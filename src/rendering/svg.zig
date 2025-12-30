const std = @import("std");
const root = @import("../root.zig");

pub fn svgToBitmap(svg: []const u8, width: u32, height: u32) ![]u8 {
	_ = svg;
	_ = width;
	_ = height;
	const document = root.c.plutosvg_document_load_from_file("icon.svg", -1, -1);
	if (document == null) {
		return root.ZError.NotImplemented;
	}
	const surface = root.c.plutosvg_document_render_to_surface(document, null, -1, -1, null, null, null);
	_ = root.c.plutovg_surface_write_to_png(surface, "camera.png");
	root.c.plutosvg_document_destroy(document);
	root.c.plutovg_surface_destroy(surface);
	return root.ZError.NotImplemented;
}
