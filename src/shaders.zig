pub const core = @import("core/root.zig");

// all the builtin shaders

pub const container = @import("shaders/container.zig");
pub const bitmap = @import("shaders/bitmap.zig");
pub const font = @import("shaders/font.zig");

/// registers all builtin shaders
pub fn registerAllFunc(context: *core.ZContext) anyerror!void {
	container.register(context);
	bitmap.register(context);
	font.register(context);
}
