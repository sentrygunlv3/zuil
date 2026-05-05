const std = @import("std");
pub const glfw = @import("glfw");
pub const opengl = @import("opengl");
pub const gl = opengl.bindings;

pub const ZuilCore = @import("zuilcore");

pub const inputGlfw = @import("input.zig");
pub const ZWindow = @import("window.zig").ZWindow;

pub const OpenglBackend = @import("backend/opengl.zig").ZRenderFIOpengl;

pub var allocator: std.mem.Allocator = undefined;
pub var context: *ZuilCore.ZContext = undefined;
pub var windows: std.AutoHashMap(*glfw.Window, *ZWindow) = undefined;
pub var main_window: ?*ZWindow = null;
pub var modifiers = ZuilCore.input.ZModifiers{};

pub var createContext: ?*const fn (context: *ZuilCore.ZContext) anyerror!void = null;

pub const ZAppError = error{
	NoWindowsCreated,
};

pub fn init(a: std.mem.Allocator, theme: *ZuilCore.Theme) !void {
	allocator = a;

	_ = glfw.setErrorCallback(errorCallback);
	try glfw.init();

	windows = std.AutoHashMap(*glfw.Window, *ZWindow).init(allocator);

	context = try ZuilCore.ZContext.init(allocator, OpenglBackend, theme);
	context.log(.info, "ZUIL init", .{});
}

pub fn deinit() void {
	windows.deinit();

	context.log(.info, "ZUIL deinit", .{});
	context.deinit();

	glfw.terminate();
}

pub fn run() !void {
	if (windows.count() == 0) {
		return ZAppError.NoWindowsCreated;
	}

	var running = true;
	while (running) {
		if (windows.count() == 0) {
			running = false;
			break;
		}
		var iterator = windows.valueIterator();
		while (iterator.next()) |window| {
			const value = window.*.process() catch |e| {
				context.log(.err, "{}", .{e});
				return;
			};
			if (!value) {
				if (window.* == main_window.?) {
					running = false;
				}
				window.*.deinit();
				break;
			}
		}
		glfw.waitEventsTimeout(0.016);
	}
}

fn errorCallback(error_code: c_int, desc: ?[*:0]const u8) callconv(.c) void {
	if (desc) |d| {
		std.log.err("glfw {} - {s}", .{error_code, std.mem.span(d)});
	} else {
		std.log.err("glfw {}", .{error_code});
	}
}
