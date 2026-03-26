const std = @import("std");

pub const core = @import("zuilcore");
pub const app = @import("app/app.zig");
pub const widgets = @import("widgets/widgets.zig");

pub const assets = core.assets;
pub const widget = core.widget;
pub const input = core.input;
pub const types = core.types;

pub const ZWindow = app.ZWindow;

/// helper that setups builtins and calls the core init
pub fn init(a: std.mem.Allocator) !void {
	try app.init(a);
	assets.init(a);
	app.createContext = widgets.registerAllFunc;
}

pub fn deinit() void {
	assets.deinit();
	app.deinit();
}

pub const run = app.run;

comptime {
	_ = core.cffi;
}
