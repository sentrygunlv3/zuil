const std = @import("std");
pub const glfw = @import("glfw");
pub const opengl = @import("opengl");

pub const c = @cImport({
	@cInclude("plutosvg.h");
});

pub const gl = opengl.bindings;

pub const color = @import("types/color.zig");
pub const input = @import("types/input.zig");
pub const types = @import("types/generic.zig");
pub const zwidget = @import("widget/base.zig");
pub const assets = @import("assets/asset_registry.zig");
pub const shader = @import("rendering/shader_registry.zig");
pub const renderer = @import("rendering/renderer.zig");
pub const svg = @import("assets/helpers/svg.zig");

pub const ZWidgetTree = @import("tree.zig").ZWidgetTree;
pub const ZError = @import("types/error.zig").ZError;
pub const ZBitmap = @import("types/bitmap.zig").ZBitmap;
pub const ZAsset = @import("types/asset.zig").ZAsset;

pub var allocator: std.mem.Allocator = undefined;

pub var onContextCreate: ?*const fn (self: *renderer.context.RendererContext) anyerror!void = null;
