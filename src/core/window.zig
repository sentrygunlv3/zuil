const std = @import("std");
const root = @import("root.zig");

const gl = root.gl;
const glfw = root.glfw;
const input = root.input;
const zwidget = root.zwidget;
const types = root.types;

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
	// ---
	context: *root.renderer.context.RendererContext = undefined,
	flags: packed struct {
		layout_dirty: bool = true,
		render_dirty: bool = true,
		render_dirty_full: bool = true,
		shared_contex: bool = false,
		_: u4 = 0,
	} = .{},
	dirty: ?types.ZBounds = .zero(),
	// --- input
	key_events: std.ArrayList(input.ZEvent) = undefined,
	focused_widget: ?*zwidget.ZWidget = null,
	/// return true to pass input to widget tree
	input_handler: ?*const fn (self: *@This(), event: input.ZEvent) bool = null,
	// ---
	root: ?*zwidget.ZWidget = undefined,
	content_alignment: types.ZAlign = .default(),
	display_size: struct {x: f32, y: f32} = .{.x = 0, .y = 0},

	pub fn init(width: i32, height: i32, title: [:0]const u8, root_widget: ?*zwidget.ZWidget) !*@This() {
		const self = try root.allocator.create(@This());
		errdefer self.deinit();

		if (root.main_window) |main| {
			self.* = .{
				.window = try createWindow(width, height, title, null, main.window),
				.key_events = try std.ArrayList(input.ZEvent).initCapacity(root.allocator, 0),
				.root = root_widget,
			};
			self.flags.shared_contex = true;

			glfw.makeContextCurrent(self.window);
		} else {
			self.* = .{
				.window = try glfw.Window.create(width, height, title, null),
				.key_events = try std.ArrayList(input.ZEvent).initCapacity(root.allocator, 0),
				.root = root_widget,
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

		if (glfw.getPrimaryMonitor()) |monitor| {
			const mode = try monitor.getVideoMode();
			const size = try monitor.getPhysicalSize();

			self.display_size = .{
				.x = @as(f32, @floatFromInt(mode.width)) / @as(f32, @floatFromInt(size[0])),
				.y = @as(f32, @floatFromInt(mode.height)) / @as(f32, @floatFromInt(size[1])),
			};
		}

		if (root.main_window.? != self) {
			self.context = root.main_window.?.context;
		} else {
			self.context = try root.renderer.context.RendererContext.init();
			try root.onContextCreate.?(self.context);
		}

		if (self.root) |r| {
			r.setWindow(self);
		}

		try root.windows.put(self.window, self);
		return self;
	}

	pub fn initRenderTexture(self: *@This(), w: i32, h: i32) void {
		gl.genTextures(1, &self.render_texture);
		gl.bindTexture(gl.TEXTURE_2D, self.render_texture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
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
		if (self.root) |r| {
			r.destroy();
		}
		_ = root.windows.remove(self.window);
		if (!self.flags.shared_contex) {
			self.context.deinit();
		}
		self.window.destroy();
		self.key_events.deinit(root.allocator);
		root.allocator.destroy(self);
	}

	pub fn setRoot(self: *@This(), root_widget: ?*zwidget.ZWidget) void {
		if (self.root) |r| {
			r.destroy();
		}
		self.root = root_widget;
	}

	pub fn markDirty(self: *@This()) void {
		self.flags.layout_dirty = true;
	}

	pub fn markDirtyRender(self: *@This(), area: types.ZBounds) void {
		self.flags.render_dirty = true;

		if (self.dirty != null) {
			self.dirty.?.x = @min(self.dirty.?.x, area.x);
			self.dirty.?.y = @min(self.dirty.?.y, area.y);
			self.dirty.?.w = @max(self.dirty.?.w, area.w);
			self.dirty.?.h = @max(self.dirty.?.h, area.h);
		} else {
			self.dirty = area;
		}
	}

	pub fn setContentAlignment(self: *@This(), new: types.ZAlign) void {
		self.content_alignment = new;
		self.root.markDirty();
		self.markDirty();
	}

	fn mouseButtonCallback(window: *glfw.Window, button: glfw.MouseButton, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
		_ = mods;
		var posx: f64 = 0;
		var posy: f64 = 0;
		glfw.getCursorPos(window, &posx, &posy);
		const event = input.ZEvent{
			.mouse = .{
				.key = input.ZMouseKey.fromGlfw(button),
				.action = .fromGlfw(action),
				.modifiers = root.modifiers,
				.x = @floatCast(posx),
				.y = @floatCast(posy),
			}
		};

		root.windows.get(window).?.key_events.append(root.allocator, event) catch |e| {
			std.log.err("mouseButtonCallback {}", .{e});
		};
	}

	fn keyCallback(window: *glfw.Window, key: glfw.Key, scancode: c_int, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
		_ = mods;
		const event = processGlfwKey(key, scancode, action);

		root.windows.get(window).?.key_events.append(root.allocator, event) catch |e| {
			std.log.err("keyCallback {}", .{e});
		};
	}

	fn processGlfwKey(key: glfw.Key, scancode: c_int, action: glfw.Action) input.ZEvent {
		const ukey = input.ZKey.fromGlfw(key);
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
				.action = .fromGlfw(action),
				.modifiers = root.modifiers,
				.scan_code = scancode,
			}
		};
	}

	fn resizeCallback(window: *glfw.Window, w: c_int, h: c_int) callconv(.c) void {
		glfw.makeContextCurrent(window);
		root.gl.viewport(0, 0, w, h);
		if (root.windows.get(window)) |win| {
			if (win.root) |r| {
				r.markDirty();
			}
			win.flags.render_dirty_full = true;

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

	pub fn getBounds(self: *@This()) types.ZBounds {
		const size = self.window.getSize();
		return .{
			.x = 0,
			.y = 0,
			.w = @floatFromInt(size[0]),
			.h = @floatFromInt(size[1]),
		};
	}

	pub fn process(self: *@This()) bool {
		if (self.window.shouldClose()) {
			return false;
		}
		if (self.key_events.items.len != 0) {
			std.debug.print("\n--- process input ---\n", .{});
			for (self.key_events.items) |event| {
				if (self.input_handler) |func| {
					if (!func(self, event)) {
						continue;
					}
					switch (event) {
						.key => {
							if (self.focused_widget) |focused| {
								std.debug.print("{*}\n", .{focused});
								focused.event(event) catch |e| {
									std.log.err("event: {}", .{e});
								};
							}
						},
						.mouse => {
							if (self.root) |r| {
								if (r.isOverPoint(event.mouse.x, event.mouse.y, false)) |hovered| {
									std.debug.print("{*}\n", .{hovered});
									hovered.event(event) catch |e| {
										std.log.err("event: {}", .{e});
									};
								} else {
									std.debug.print("nothing hovered\n", .{});
								}
							}
						},
						else => {}
					}
				}
			}
			self.key_events.clearAndFree(root.allocator);
		}
		if (self.flags.layout_dirty) {
			std.debug.print("\n--- process layout ---\n", .{});

			self.layout() catch |e| {
				std.log.err("layout: {}", .{e});
			};

			std.debug.print("\n--- process render ---\n", .{});

			self.render() catch |e| {
				std.log.err("failed to render window: {}\n", .{e});
				switch (e) {
					root.ZError.MissingShader => {
						root.shader.debugPrintAll(self.context);
					},
					else => {}
				}
			};
		} else if (self.flags.render_dirty) {
			std.debug.print("\n--- process render ---\n", .{});

			self.render() catch |e| {
				std.log.err("failed to render window: {}\n", .{e});
				switch (e) {
					root.ZError.MissingShader => {
						root.shader.debugPrintAll(self.context);
					},
					else => {}
				}
			};
		}
		return true;
	}

	pub fn layout(self: *@This()) anyerror!void {
		const space = self.getBounds();

		if (self.root) |r| {
			try r.updatePreferredSize(if (r.flags.layout_dirty) true else false, space.w, space.h);
			try r.updateActualSize(if (r.flags.layout_dirty) true else false, space.w, space.h);
			try r.updatePosition(if (r.flags.layout_dirty) true else false, space.w, space.h);
		}

		self.flags.layout_dirty = false;
	}

	pub fn render(self: *@This()) anyerror!void {
		std.debug.print("area: {}\nflags: {}\n", .{if (self.dirty != null) self.dirty.? else types.ZBounds.zero(), self.flags});

		glfw.makeContextCurrent(self.window);

		var width: i32 = undefined;
		var height: i32 = undefined;
		glfw.getFramebufferSize(self.window, &width, &height);

		root.gl.bindFramebuffer(root.gl.FRAMEBUFFER, self.render_frame);

		gl.viewport(0, 0, width, height);

		if (self.root) |r| {
			var commands = try std.ArrayList(*root.renderer.RenderCommand).initCapacity(root.allocator, 16);
			defer commands.deinit(root.allocator);

			var area = if (self.flags.render_dirty_full) null else self.dirty;

			try r.render(
				self,
				&commands,
				area
			);
			std.debug.print("total commands: {}\n", .{commands.items.len});

			if (area != null) {
				// to opengl coordinates
				area.?.y = self.getBounds().h - area.?.h - area.?.y;
			}
			root.renderer.clip(area);
			root.renderer.clear(root.color.GREY);
			try root.renderer.renderCommands(
				self.context,
				&commands
			);
		}
		gl.disable(gl.SCISSOR_TEST);

		gl.bindFramebuffer(gl.READ_FRAMEBUFFER, self.render_frame);
		gl.bindFramebuffer(gl.DRAW_FRAMEBUFFER, 0);

		gl.blitFramebuffer(
			0, 0, width, height,
			0, 0, width, height,
			gl.COLOR_BUFFER_BIT,
			gl.LINEAR
		);

		self.window.swapBuffers();
		self.flags.render_dirty = false;
		self.flags.render_dirty_full = false;
		self.dirty = null;
	}
};
