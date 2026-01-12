pub const shader = @import("core/rendering/shader_registry.zig");
pub const renderer = @import("core/rendering/renderer.zig");
pub const core = @import("core/root.zig");

// all the builtin shaders

pub const container = @import("shaders/container.zig");
pub const bitmap = @import("shaders/bitmap.zig");

/// registers all builtin shaders
pub fn registerAll() void {
	core.onWindowCreate = registerAllFunc;
}

fn registerAllFunc(self: *core.ZWindow) anyerror!void {
	container.register(&self.context);
	bitmap.register(&self.context);
}
