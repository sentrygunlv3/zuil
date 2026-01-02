const std = @import("std");
pub const glfw = @import("glfw");
pub const opengl = @import("opengl");

pub const c = @cImport({
	@cInclude("plutosvg.h");
});

pub const gl = opengl.bindings;

pub const widgets = @import("widgets.zig");
pub const shaders = @import("shaders.zig");

pub const color = @import("core/types/color.zig");
pub const input = @import("core/types/input.zig");
pub const types = @import("core/types/generic.zig");
pub const zwidget = @import("core/widget/base.zig");
pub const assets = @import("core/assets/asset_registry.zig");
pub const shader = @import("core/rendering/shader_registry.zig");
pub const svg = @import("core/assets/helpers/svg.zig");

pub const ZWindow = @import("core/window.zig").ZWindow;
pub const ZError = @import("core/types/error.zig").ZError;
pub const ZBitmap = @import("core/types/bitmap.zig").ZBitmap;
pub const ZAsset = @import("core/types/asset.zig").ZAsset;

pub var allocator: std.mem.Allocator = undefined;
pub var windows: std.AutoHashMap(*glfw.Window, *ZWindow) = undefined;

pub var modifiers = input.ZModifiers{};

pub fn init(a: std.mem.Allocator) !void {
	allocator = a;

	_ = glfw.setErrorCallback(errorCallback);
	try glfw.init();

	shader.init(allocator);
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
	shaders.registerAll();

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
