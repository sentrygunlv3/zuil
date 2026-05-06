const std = @import("std");
const root = @import("app.zig");

const gl = root.gl;
const glfw = root.glfw;
const input = root.ZuilCore.input;
const widget = root.ZuilCore.widget;
const types = root.ZuilCore.types;

// EGL slop
var current: ?*glfw.Window = null;

fn makeContextCurrent(new: *glfw.Window) void {
	if (current == new) return;
	if (current != null) {
		gl.finish();
	}
	glfw.makeContextCurrent(new);
	current = new;
}

pub const ZWindow = struct {
	window: *glfw.Window = undefined,
	render_texture: u32 = 0,
	render_frame: u32 = 0,
	tree: *root.ZuilCore.tree.ZWidgetTree = undefined,
	input_handler: ?*const fn (self: *@This(), event: input.ZEvent) bool = null,

	pub fn init(width: u32, height: u32, title: [:0]const u8, root_widget: ?*widget.ZWidget) !*@This() {
		const self = try root.allocator.create(@This());
		errdefer self.deinit();

		if (root.main_window) |main| {
			self.* = .{
				.window = try glfw.Window.create(@intCast(width), @intCast(height), title, null, main.window),
			};

			makeContextCurrent(self.window);
		} else {
			self.* = .{
				.window = try glfw.Window.create(@intCast(width), @intCast(height), title, null, null),
			};
			root.main_window = self;

			makeContextCurrent(self.window);

			glfw.swapInterval(0);

			try root.opengl.loadCoreProfile(glfw.getProcAddress, 4, 0);

			root.gl.enable(root.gl.BLEND);
			root.gl.blendFunc(root.gl.SRC_ALPHA, root.gl.ONE_MINUS_SRC_ALPHA);

			try root.context.lateInit();

			if (root.createContext) |func| {
				try func(root.context);
			}
		}

		self.initRenderTexture();

		const arrow_cursor = try glfw.createStandardCursor(.arrow);
		glfw.setCursor(self.window, arrow_cursor);

		_ = glfw.setWindowSizeCallback(self.window, resizeCallback);
		_ = glfw.setWindowContentScaleCallback(self.window, contentScaleCallback);

		_ = glfw.setKeyCallback(self.window, keyCallback);
		_ = glfw.setMouseButtonCallback(self.window, mouseButtonCallback);

		var size_x: f32 = 0;
		var size_y: f32 = 0;
		if (glfw.getPrimaryMonitor()) |monitor| {
			const mode = try monitor.getVideoMode();
			const size = try monitor.getPhysicalSize();

			size_x = @as(f32, @floatFromInt(mode.width)) / @as(f32, @floatFromInt(size[0]));
			size_y = @as(f32, @floatFromInt(mode.height)) / @as(f32, @floatFromInt(size[1]));
		}

		const scaling = self.window.getContentScale();

		self.tree = try .init(
			.{.w = size_x, .h = size_y},
			.{.w = scaling[0], .h = scaling[1]},
			root_widget,
			root.context
		);

		const size = self.window.getSize();
		self.tree.current_bounds = .{
			.x = 0,
			.y = 0,
			.w = @floatFromInt(size[0]),
			.h = @floatFromInt(size[1]),
		};

		try root.windows.put(self.window, self);
		return self;
	}

	pub fn initRenderTexture(self: *@This()) void {
		makeContextCurrent(self.window);
		gl.genTextures(1, &self.render_texture);
		gl.bindTexture(gl.TEXTURE_2D, self.render_texture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
		const size = self.window.getFramebufferSize();
		gl.texImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGBA,
			size[0],
			size[1],
			0,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			null
		);

		gl.genFramebuffers(1, &self.render_frame);
		gl.bindFramebuffer(gl.FRAMEBUFFER, self.render_frame);
		gl.framebufferTexture2D(
			gl.FRAMEBUFFER, 
			gl.COLOR_ATTACHMENT0, 
			gl.TEXTURE_2D, 
			self.render_texture, 
			0
		);

		gl.bindFramebuffer(gl.FRAMEBUFFER, 0);
	}

	pub fn deinit(self: *@This()) void {
		self.tree.deinit();
		_ = root.windows.remove(self.window);
		self.window.destroy();
		root.allocator.destroy(self);
	}

	fn mouseButtonCallback(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
		_ = mods;
		var posx: f64 = 0;
		var posy: f64 = 0;
		glfw.getCursorPos(window, &posx, &posy);
		const event = input.ZEvent{
			.mouse = .{
				.key = root.inputGlfw.mouseKeyFromGlfw(button),
				.action = root.inputGlfw.actionFromGlfw(action),
				.modifiers = root.modifiers,
				.x = @floatCast(posx),
				.y = @floatCast(posy),
			}
		};

		root.windows.get(window).?.tree.key_events.append(root.allocator, event) catch |e| {
			std.log.err("mouseButtonCallback {}", .{e});
		};
	}

	fn keyCallback(window: *glfw.Window, key: glfw.Key, scancode: c_int, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
		_ = mods;
		const event = processGlfwKey(key, scancode, action);

		root.windows.get(window).?.tree.key_events.append(root.allocator, event) catch |e| {
			std.log.err("keyCallback {}", .{e});
		};
	}

	fn processGlfwKey(key: glfw.Key, scancode: c_int, action: glfw.Action) input.ZEvent {
		const ukey = root.inputGlfw.keyFromGlfw(key);
		const state = if (action != glfw.Action.release) true else false;

		switch (ukey) {
			.left_shift => root.modifiers.left_shift = state,
			.right_shift => root.modifiers.right_shift = state,
			.left_control => root.modifiers.left_control = state,
			.right_control => root.modifiers.right_control = state,
			.left_alt => root.modifiers.left_alt = state,
			.right_alt => root.modifiers.right_alt = state,
			.left_super => root.modifiers.left_super = state,
			.right_super => root.modifiers.right_super = state,
			else => {},
		}

		return .{
			.key = .{
				.key = ukey,
				.action = root.inputGlfw.actionFromGlfw(action),
				.modifiers = root.modifiers,
				.scan_code = scancode,
			}
		};
	}

	fn contentScaleCallback(window: *glfw.Window, w: f32, h: f32) callconv(.c) void {
		if (root.windows.get(window)) |win| {
			if (win.tree.root) |r| {
				r.markDirty();
			}
			win.tree.flags.render_dirty_full = true;

			win.tree.scaling = .{
				.x = w,
				.y = h,
			};

			const size = window.getFramebufferSize();

			makeContextCurrent(window);
			root.gl.viewport(0, 0, size[0], size[1]);

			gl.bindTexture(gl.TEXTURE_2D, win.render_texture);
			gl.texImage2D(
				gl.TEXTURE_2D,
				0,
				gl.RGBA,
				size[0],
				size[1],
				0,
				gl.RGBA,
				gl.UNSIGNED_BYTE,
				null
			);
			gl.bindTexture(gl.TEXTURE_2D, 0);
		}
	}

	fn resizeCallback(window: *glfw.Window, w: c_int, h: c_int) callconv(.c) void {
		if (root.windows.get(window)) |win| {
			if (win.tree.root) |r| {
				r.markDirty();
			}
			win.tree.flags.render_dirty_full = true;

			const size = win.window.getSize();
			win.tree.current_bounds = .{
				.x = 0,
				.y = 0,
				.w = @floatFromInt(size[0]),
				.h = @floatFromInt(size[1]),
			};

			makeContextCurrent(window);
			root.gl.viewport(0, 0, w, h);

			gl.bindTexture(gl.TEXTURE_2D, win.render_texture);
			gl.texImage2D(
				gl.TEXTURE_2D,
				0,
				gl.RGBA,
				@intFromFloat(@as(f32, @floatFromInt(w)) * win.tree.scaling.x),
				@intFromFloat(@as(f32, @floatFromInt(h)) * win.tree.scaling.y),
				0,
				gl.RGBA,
				gl.UNSIGNED_BYTE,
				null
			);
			gl.bindTexture(gl.TEXTURE_2D, 0);
		}
	}

	pub fn process(self: *@This()) !bool {
		if (self.window.shouldClose()) {
			return false;
		}
		if (self.tree.key_events.items.len != 0) {
			root.context.log(.debug, "--- process input ---", .{});
			for (self.tree.key_events.items) |event| {
				if (self.input_handler) |func| {
					if (!func(self, event)) {
						continue;
					}
				}
				switch (event) {
					.key => {
						if (self.tree.focused_widget) |focused| {
							root.context.log(.debug, "{*}", .{focused});
							try focused.event(event);
						}
					},
					.mouse => {
						if (self.tree.root) |r| {
							if (r.isOverPoint(event.mouse.x, event.mouse.y, false)) |hovered| {
								root.context.log(.debug, "{*}", .{hovered});
								try hovered.event(event);
							} else {
								root.context.log(.debug, "nothing hovered", .{});
							}
						}
					},
					else => {}
				}
			}
			self.tree.key_events.clearAndFree(root.allocator);
		}

		if (self.tree.flags.layout_dirty) {
			root.context.log(.debug, "--- process layout ---", .{});

			try self.tree.layout();
		}
		if (self.tree.flags.layout_dirty or self.tree.flags.render_dirty) {
			root.context.log(.debug, "--- process render ---", .{});

			try self.render();
		}
		return true;
	}

	pub fn render(self: *@This()) anyerror!void {
		// any other windows that share the context crash here
		// if you change this to the main windows context and add "makeContextCurrent(self.window);" before swapBuffers
		// it doesnt crash and the windows spawn but they render blank
		//
		// no idea how to fix this without having to create a completely separate zuil context for each window
		makeContextCurrent(self.window);

		var width: i32 = undefined;
		var height: i32 = undefined;
		glfw.getFramebufferSize(self.window, &width, &height);

		root.gl.bindFramebuffer(gl.FRAMEBUFFER, self.render_frame);

		gl.viewport(0, 0, width, height);

		try self.tree.render();

		gl.bindFramebuffer(gl.READ_FRAMEBUFFER, self.render_frame);
		gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);

		gl.blitFramebuffer(
			0, 0, width, height,
			0, 0, width, height,
			gl.COLOR_BUFFER_BIT,
			gl.LINEAR
		);

		self.window.swapBuffers();
	}
};
