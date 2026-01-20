const std = @import("std");
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
pub const renderer = @import("rendering/renderer.zig");
pub const svg = @import("assets/helpers/svg.zig");

pub const ZWidgetTree = @import("tree.zig").ZWidgetTree;
pub const ZError = @import("types/error.zig").ZError;
pub const ZBitmap = @import("types/bitmap.zig").ZBitmap;
pub const ZAsset = @import("types/asset.zig").ZAsset;

pub var onContextCreate: ?*const fn (context: *renderer.context.RenderContext) anyerror!void = null;

pub var allocator: std.mem.Allocator = undefined;
pub var render_fi: renderer.ZRenderFI = undefined;

pub fn init(a: std.mem.Allocator, backend: renderer.ZRenderFI) anyerror!void {
	allocator = a;
	render_fi = backend;

	try renderer.init();
}

pub fn deinit() void {
	renderer.deinit();
}
