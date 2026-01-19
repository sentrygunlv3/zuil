const std = @import("std");
const root = @import("app.zig");

const gl = root.gl;
const glfw = root.glfw;
const input = root.ZuilCore.input;
const zwidget = root.ZuilCore.zwidget;
const types = root.ZuilCore.types;

/// glfw.Window.create is missing share
pub fn createWindow(
    width: c_int,
    height: c_int,
    title: [:0]const u8,
    monitor: ?*glfw.Monitor,
	share: ?*glfw.Window,
) glfw.Error!*glfw.Window {
    if (glfwCreateWindow(width, height, title, monitor, share)) |window| return window;
    try glfw.maybeError();
    unreachable;
}
extern fn glfwCreateWindow(
    width: c_int,
    height: c_int,
    title: [*:0]const u8,
    monitor: ?*glfw.Monitor,
    share: ?*glfw.Window,
) ?*glfw.Window;

pub const ZWindow = struct {
	window: *glfw.Window = undefined,
	render_texture: u32 = 0,
	render_frame: u32 = 0,
	tree: *root.ZuilCore.ZWidgetTree = undefined,
	input_handler: ?*const fn (self: *@This(), event: input.ZEvent) bool = null,

	pub fn init(width: i32, height: i32, title: [:0]const u8, root_widget: ?*zwidget.ZWidget) !*@This() {
		const self = try root.allocator.create(@This());
		errdefer self.deinit();

		if (root.main_window) |main| {
			self.* = .{
				.window = try createWindow(width, height, title, null, main.window),
			};

			glfw.makeContextCurrent(self.window);
		} else {
			self.* = .{
				.window = try glfw.Window.create(width, height, title, null),
			};
			root.main_window = self;

			glfw.makeContextCurrent(self.window);

			try root.opengl.loadCoreProfile(glfw.getProcAddress, 4, 0);

			root.gl.enable(root.gl.BLEND);
			root.gl.blendFunc(root.gl.SRC_ALPHA, root.gl.ONE_MINUS_SRC_ALPHA);
		}

		self.initRenderTexture(width, height);

		const arrow_cursor = try glfw.createStandardCursor(.arrow);
		glfw.setCursor(self.window, arrow_cursor);

		_ = glfw.setWindowSizeCallback(self.window, resizeCallback);
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

		if (root.main_window.? != self) {
			self.tree = try .init(size_x, size_y, root_widget, root.main_window.?.tree.context);
		} else {
			self.tree = try .init(size_x, size_y, root_widget, null);
		}

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

	pub fn initRenderTexture(self: *@This(), w: i32, h: i32) void {
		gl.genTextures(1, &self.render_texture);
		gl.bindTexture(gl.TEXTURE_2D, self.render_texture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
		gl.texImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGBA,
			w,
			h,
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

	fn resizeCallback(window: *glfw.Window, w: c_int, h: c_int) callconv(.c) void {
		glfw.makeContextCurrent(window);
		root.gl.viewport(0, 0, w, h);
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

			gl.bindTexture(gl.TEXTURE_2D, win.render_texture);
			gl.texImage2D(
				gl.TEXTURE_2D,
				0,
				gl.RGBA,
				w,
				h,
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
			if (@import("build_options").debug) std.debug.print("\n--- process input ---\n", .{});
			for (self.tree.key_events.items) |event| {
				if (self.input_handler) |func| {
					if (!func(self, event)) {
						continue;
					}
					switch (event) {
						.key => {
							if (self.tree.focused_widget) |focused| {
								if (@import("build_options").debug) std.debug.print("{*}\n", .{focused});
								try focused.event(event);
							}
						},
						.mouse => {
							if (self.tree.root) |r| {
								if (r.isOverPoint(event.mouse.x, event.mouse.y, false)) |hovered| {
									if (@import("build_options").debug) std.debug.print("{*}\n", .{hovered});
									try hovered.event(event);
								} else {
									if (@import("build_options").debug) std.debug.print("nothing hovered\n", .{});
								}
							}
						},
						else => {}
					}
				}
			}
			self.tree.key_events.clearAndFree(root.allocator);
		}
		const Timer = std.time.Timer;
		if (self.tree.flags.layout_dirty) {
			if (@import("build_options").debug) std.debug.print("\n--- process layout ---\n", .{});
			var timer = try Timer.start();

			try self.tree.layout();
			if (@import("build_options").debug) std.debug.print("time: {d:.3}ms\n", .{@as(f64, @floatFromInt(timer.read())) / std.time.ns_per_ms});
		}
		if (self.tree.flags.layout_dirty or self.tree.flags.render_dirty) {
			if (@import("build_options").debug) std.debug.print("\n--- process render ---\n", .{});
			var timer = try Timer.start();

			try self.render();
			if (@import("build_options").debug) std.debug.print("time: {d:.3}ms\n", .{@as(f64, @floatFromInt(timer.read())) / std.time.ns_per_ms});
		}
		return true;
	}

	pub fn render(self: *@This()) anyerror!void {
		const Timer = std.time.Timer;
		var timer = try Timer.start();
		glfw.makeContextCurrent(self.window);

		var width: i32 = undefined;
		var height: i32 = undefined;
		glfw.getFramebufferSize(self.window, &width, &height);

		root.gl.bindFramebuffer(root.gl.FRAMEBUFFER, self.render_frame);

		gl.viewport(0, 0, width, height);

		if (@import("build_options").debug) std.debug.print("start: {d:.3}ms\n", .{@as(f64, @floatFromInt(timer.read())) / std.time.ns_per_ms});

		timer = try Timer.start();

		try self.tree.render();
		if (@import("build_options").debug) std.debug.print("tree: {d:.3}ms\n", .{@as(f64, @floatFromInt(timer.read())) / std.time.ns_per_ms});

		timer = try Timer.start();

		gl.bindFramebuffer(gl.READ_FRAMEBUFFER, self.render_frame);
		gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);

		gl.blitFramebuffer(
			0, 0, width, height,
			0, 0, width, height,
			gl.COLOR_BUFFER_BIT,
			gl.LINEAR
		);

		self.window.swapBuffers();
		
		if (@import("build_options").debug) std.debug.print("blit: {d:.3}ms\n", .{@as(f64, @floatFromInt(timer.read())) / std.time.ns_per_ms});
	}
};
