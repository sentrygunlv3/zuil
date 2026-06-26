const std = @import("std");

pub const core = @import("zuilcore");
pub const app = @import("app.zig");

pub const assets = core.assets;
pub const widget = core.widget;
pub const input = core.input;
pub const types = core.types;

pub const ZWindow = app.ZWindow;

comptime {
	_ = core.cffi;
}
