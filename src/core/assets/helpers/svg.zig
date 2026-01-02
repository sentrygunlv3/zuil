const std = @import("std");
const root = @import("../../../root.zig");
const ZBitmap = root.ZBitmap;

pub fn svgToBitmap(svg: root.ZAsset, width: u32, height: u32) anyerror!ZBitmap {
	if (svg.type != .svg) {
		return root.ZError.WrongAssetType;
	}

	var document: ?*root.c.struct_plutosvg_document = null;
	switch (svg.data) {
		.compile_time => {
			document = root.c.plutosvg_document_load_from_data(
				svg.data.compile_time.ptr,
				@intCast(svg.data.compile_time.len),
				-1,
				-1,
				null,
				null
			);
		},
		.runtime => {
			document = root.c.plutosvg_document_load_from_data(
				svg.data.runtime.ptr,
				@intCast(svg.data.runtime.len),
				-1,
				-1,
				null,
				null
			);
		},
	}

	if (document == null) {
		return root.ZError.FailedToCreateSvg;
	}
	defer root.c.plutosvg_document_destroy(document);

	const surface = root.c.plutosvg_document_render_to_surface(document, null, @intCast(width), @intCast(height), null, null, null);
	if (surface == null) {
		return root.ZError.FailedToCreateSvg;
	}
	defer root.c.plutovg_surface_destroy(surface);

	const c_data = root.c.plutovg_surface_get_data(surface);
	const stride: u32 = @intCast(root.c.plutovg_surface_get_stride(surface));

	const size = height * stride;

	const data = c_data[0..size];

	const bitmap = try root.allocator.alloc(u8, size);
	@memcpy(bitmap, data);

	return .{
		.data = bitmap,
		.w = width,
		.h = height,
	};
}
