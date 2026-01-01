const std = @import("std");
const glfw = @import("glfw");
const opengl = @import("opengl");

pub const c = @cImport({
	@cInclude("plutosvg.h");
});

pub const gl = opengl.bindings;

pub const types = @import("types/generic.zig");
pub const ZError = @import("types/error.zig").ZError;
pub const color = @import("types/color.zig");
pub const input = @import("types/input.zig");
pub const ZBitmap = @import("types/bitmap.zig").ZBitmap;
pub const ZAsset = @import("types/asset.zig").ZAsset;
pub const zwidget = @import("zwidget.zig");

pub const widgets = @import("widgets.zig");
pub const assets = @import("assets/asset_registry.zig");
pub const shader = @import("rendering/shader_registry.zig");
pub const svg = @import("rendering/svg.zig");

pub var allocator: std.mem.Allocator = undefined;
var windows: std.AutoHashMap(*glfw.Window, *ZWindow) = undefined;

var modifiers = input.ZModifiers{};

pub fn init(a: std.mem.Allocator) !void {
	allocator = a;

	_ = glfw.setErrorCallback(errorCallback);
	try glfw.init();

	assets.init();

	windows = std.AutoHashMap(*glfw.Window, *ZWindow).init(allocator);
}

pub fn deinit() void {
	shader.deinit();
	glfw.terminate();
	assets.deinit();
	windows.deinit();
}

pub fn run() !void {
	if (windows.count() == 0) {
		return ZError.NoWindowsCreated;
	}
	try opengl.loadCoreProfile(glfw.getProcAddress, 4, 0);
	shader.init(allocator);

	var running = true;
	while (running) {
		if (windows.count() == 0) {
			running = false;
			break;
		}
		var iterator = windows.valueIterator();
		while (iterator.next()) |window| {
			if (!window.*.process()) {
				window.*.deinit();
				break;
			}
		}
		glfw.pollEvents();
	}
}

fn errorCallback(error_code: c_int, desc: ?[*:0]const u8) callconv(.c) void {
	if (desc) |d| {
		std.log.err("glfw {} - {s}", .{error_code, std.mem.span(d)});
	} else {
		std.log.err("glfw {}", .{error_code});
	}
}

pub const ZWindow = struct {
	window: *glfw.Window = undefined,
	dirty: bool = true,
	// --- input
	key_events: std.ArrayList(input.ZEvent) = undefined,
	focused_widget: ?*zwidget.ZWidget = null,
	/// return true to pass input to widget tree
	input_handler: ?*const fn (self: *@This(), event: input.ZEvent) bool = null,
	// ---
	root: *zwidget.ZWidget = undefined,
	content_alignment: types.ZAlign = .default(),
	display_size: struct {x: f32, y: f32} = .{.x = 0, .y = 0},

	pub fn init(width: i32, height: i32, title: [:0]const u8, root: *zwidget.ZWidget) !*@This() {
		const self = try allocator.create(@This());

		self.* = .{
			.window = try glfw.Window.create(width, height, title, null),
			.key_events = try std.ArrayList(input.ZEvent).initCapacity(allocator, 0),
			.root = root,
		};
		self.root.setWindow(self);

		const arrow_cursor = try glfw.createStandardCursor(.arrow);
		glfw.setCursor(self.window, arrow_cursor);

		glfw.makeContextCurrent(self.window);

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

		try windows.put(self.window, self);
		return self;
	}

	pub fn deinit(self: *@This()) void {
		self.root.destroy();
		_ = windows.remove(self.window);
		self.window.destroy();
		self.key_events.deinit(allocator);
		allocator.destroy(self);
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
				.modifiers = modifiers,
				.x = @floatCast(posx),
				.y = @floatCast(posy),
			}
		};

		windows.get(window).?.key_events.append(allocator, event) catch |e| {
			std.log.err("mouseButtonCallback {}", .{e});
		};
	}

	fn keyCallback(window: *glfw.Window, key: glfw.Key, scancode: c_int, action: glfw.Action, mods: glfw.Mods) callconv(.c) void {
		_ = mods;
		const event = processGlfwKey(key, scancode, action);

		windows.get(window).?.key_events.append(allocator, event) catch |e| {
			std.log.err("keyCallback {}", .{e});
		};
	}

	fn processGlfwKey(key: glfw.Key, scancode: c_int, action: glfw.Action) input.ZEvent {
		const ukey = input.ZKey.fromGlfw(key);
		const state = if (action != glfw.Action.release) true else false;

		switch (ukey) {
			.left_shift => modifiers.left_shift = state,
			.right_shift => modifiers.right_shift = state,
			.left_control => modifiers.left_control = state,
			.right_control => modifiers.right_control = state,
			.left_alt => modifiers.left_alt = state,
			.right_alt => modifiers.right_alt = state,
			.left_super => modifiers.left_super = state,
			.right_super => modifiers.right_super = state,
			else => {},
		}

		return .{
			.key = .{
				.key = ukey,
				.action = .fromGlfw(action),
				.modifiers = modifiers,
				.scan_code = scancode,
			}
		};
	}

	fn resizeCallback(window: *glfw.Window, w: c_int, h: c_int) callconv(.c) void {
		windows.get(window).?.dirty = true;
		gl.viewport(0, 0, w, h);
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
							if (self.root.isOverPoint(event.mouse.x, event.mouse.y, false)) |hovered| {
								std.debug.print("{*}\n", .{hovered});
								hovered.event(event) catch |e| {
									std.debug.print("{}\n", .{e});
								};
							} else {
								std.debug.print("nothing hovered\n", .{});
							}
						},
						else => {}
					}
				}
			}
			// TODO: temp dirty set
			self.dirty = true;
			self.key_events.clearAndFree(allocator);
		}
		if (self.dirty == true) {
			std.debug.print("\n--- process layout/render ---\n", .{});
			self.render() catch |e| {
				std.log.err("failed to render window: {}\n", .{e});
				switch (e) {
					ZError.MissingShader => {
						shader.debugPrintAll();
					},
					else => {}
				}
			};
		}
		return true;
	}

	pub fn render(self: *@This()) !void {
		glfw.makeContextCurrent(self.window);
		
		const clear_color = [_]f32{0.192, 0.212, 0.231, 1.0};
		gl.clearBufferfv(gl.COLOR, 0, &clear_color);

		const space = self.getBounds();
		try zwidget.updateSizeWidget(self.root, space.w, space.h, self.content_alignment);
		try self.root.update();

		try self.root.render(self);
		
		self.window.swapBuffers();
		self.dirty = false;
	}
};
