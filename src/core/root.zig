//! the root of zuil core

const std = @import("std");
pub const opengl = @import("opengl");

pub const c = @cImport({
	@cInclude("plutosvg.h");
});

pub const cffi = @import("c.zig");

pub const gl = opengl.bindings;

pub const color = @import("types/color.zig");
pub const input = @import("types/input.zig");
pub const types = @import("types/generic.zig");
pub const widget = @import("widget/base.zig");
pub const assets = @import("assets/asset_registry.zig");
pub const renderer = @import("rendering/renderer.zig");
pub const svg = @import("assets/helpers/svg.zig");
pub const tree = @import("tree.zig");
pub const errors = @import("types/error.zig");

pub const ZBitmap = @import("types/bitmap.zig").ZBitmap;
pub const ZAsset = @import("types/asset.zig").ZAsset;

/// the function thats called when a new render context is created
/// 
/// this can be used to register things like shaders to the shader hashmap
pub var onContextCreate: ?*const fn (context: *renderer.context.RenderContext) anyerror!void = null;

/// the global allocator used by the core
pub var allocator: std.mem.Allocator = undefined;

/// the global rendering function interface
/// 
/// when zuil core wants to render, create textures, ...
/// it will use the functions inside this
pub var render_fi: renderer.ZRenderFI = undefined;

pub fn init(a: std.mem.Allocator, backend: renderer.ZRenderFI) anyerror!void {
	allocator = a;
	render_fi = backend;

	try renderer.init();
}

pub fn deinit() void {
	renderer.deinit();
}
