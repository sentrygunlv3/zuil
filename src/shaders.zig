pub const renderer = @import("core/rendering/renderer.zig");
pub const core = @import("core/root.zig");

// all the builtin shaders

pub const container = @import("shaders/container.zig");
pub const bitmap = @import("shaders/bitmap.zig");

/// registers all builtin shaders
pub fn registerAllFunc(context: *core.renderer.context.RenderContext) anyerror!void {
	container.register(context);
	bitmap.register(context);
}
