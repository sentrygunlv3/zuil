pub const core = @import("core/root.zig");
pub const widgets = @import("widgets.zig");
pub const shaders = @import("shaders.zig");

pub const assets = core.assets;
pub const shader = core.shader;
pub const zwidget = core.zwidget;
pub const input = core.input;
pub const types = core.types;

pub const ZWindow = core.ZWindow;

pub const init = core.init;
pub const deinit = core.deinit;

pub fn run() !void {
	try core.runInit();
	shaders.registerAll();
	try core.runLoop();
}
