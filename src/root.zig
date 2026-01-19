const std = @import("std");

pub const core = @import("core/root.zig");
pub const app = @import("app/app.zig");
pub const widgets = @import("widgets.zig");
pub const shaders = @import("shaders.zig");

pub const assets = core.assets;
pub const shader = core.shader;
pub const zwidget = core.zwidget;
pub const input = core.input;
pub const types = core.types;

pub const ZWindow = app.ZWindow;

/// helper that setups builtins and calls the core init
pub fn init(a: std.mem.Allocator) !void {
	try app.init(a);
	assets.init();
	core.onContextCreate = shaders.registerAllFunc;
}

pub fn deinit() void {
	assets.deinit();
	app.deinit();
}

pub const run = app.run;
