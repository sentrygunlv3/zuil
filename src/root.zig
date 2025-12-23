const std = @import("std");
const glfw = @import("glfw");
const opengl = @import("opengl");

pub const gl = opengl.bindings;

pub const widget = @import("widget.zig");
pub const color = @import("color.zig");
pub const shader = @import("shader_registry.zig");

// widgets

pub const uContainer = @import("widgets/container.zig").uContainer;
pub const UList = @import("widgets/list.zig").uList;

// ---

pub var allocator: std.mem.Allocator = undefined;
var windows: std.AutoHashMap(*glfw.Window, *UWindow) = undefined;

pub const UError = error{
	NotImplemented,
	NoWindowsCreated,
	// widget
	MissingWidgetFunction,
	NoWidgetData,
	// shader
	FailedToCompileShader,
	FailedToLinkShader,
	MissingShader,
};

pub fn init(a: std.mem.Allocator) !void {
	allocator = a;

	_ = glfw.setErrorCallback(errorCallback);
	try glfw.init();

	windows = std.AutoHashMap(*glfw.Window, *UWindow).init(allocator);
}

pub fn deinit() void {
	glfw.terminate();
	windows.deinit();
}

pub fn run() !void {
	if (windows.count() == 0) {
		return UError.NoWindowsCreated;
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
			if (!window.*.attemptRender()) {
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

pub const UWindow = struct {
	window: *glfw.Window,
	dirty: bool,
	root: *widget.UWidget,
	content_alignment: widget.UAlign,

	pub fn init(width: i32, height: i32, title: [:0]const u8, root: *widget.UWidget) !*@This() {
		const self = try allocator.create(@This());

		self.window = try glfw.Window.create(width, height, title, null);
		self.dirty = true;
		self.root = root;
		self.content_alignment = widget.UAlign.default();

		glfw.makeContextCurrent(self.window);

		_ = glfw.setWindowSizeCallback(self.window, resizeCallback);

		try windows.put(self.window, self);
		return self;
	}

	pub fn deinit(self: *@This()) void {
		self.root.deinit();
		_ = windows.remove(self.window);
		self.window.destroy();
		allocator.destroy(self);
	}

	fn resizeCallback(window: *glfw.Window, a: c_int, b: c_int) callconv(.c) void {
		windows.get(window).?.dirty = true;
		gl.viewport(0, 0, a, b);
	}

	pub fn getSize(self: *@This()) widget.UBounds {
		const size = self.window.getSize();
		return .{
			.w = @floatFromInt(size[0]),
			.h = @floatFromInt(size[1]),
		};
	}

	pub fn attemptRender(self: *@This()) bool {
		if (self.window.shouldClose()) {
			return false;
		}
		if (self.dirty == true) {
			self.render() catch |e| {
				std.log.err("failed to render window: {}\n", .{e});
				switch (e) {
					UError.MissingShader => {
						shader.debugPrintAll();
					},
					else => {}
				}
			};
		}
		return true;
	}

	pub fn render(self: *@This()) !void {
		std.debug.print("\n--- render ---\n", .{});

		glfw.makeContextCurrent(self.window);
		
		const clear_color = [_]f32{0.192, 0.212, 0.231, 1.0};
		gl.clearBufferfv(gl.COLOR, 0, &clear_color);

		try self.root.update(self);

		try self.root.render(self);
		
		self.window.swapBuffers();
		self.dirty = false;
	}
};
