pub const shader = @import("core/rendering/shader_registry.zig");

// all the builtin shaders

pub const container = @import("shaders/container.zig");
pub const bitmap = @import("shaders/bitmap.zig");

/// registers all builtin shaders
pub fn registerAll() void {
	container.register();
	bitmap.register();
}
