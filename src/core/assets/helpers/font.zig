const std = @import("std");
const root = @import("../../root.zig");

const ft = root.ft;
const hb = root.hb;

const ZBitmap = root.ZBitmap;
const ZError = root.errors.ZError;

pub const ZFont = struct {
	texture: ZBitmap = undefined,
	face: ft.FT_Face = undefined,
	hb_font: *root.hb.struct_hb_font_t = undefined,
	glyphs: std.ArrayList(glyph) = undefined,

	pub const glyph = struct {
		x: i32,
		y: i32,
		w: i32,
		h: i32,
		bearing_x: i32,
		bearing_y: i32,
		advance: i32,
	};

	pub fn init() !*@This() {
		return try root.allocator.create(@This());
	}

	pub fn deinit(self: *@This()) void {
		hb.hb_font_create(&self.hb_font);
		self.texture.deinit();
		root.allocator.destroy(self);
	}
};

pub fn ttfToFont(svg: root.ZAsset, width: u32, height: u32) anyerror!*ZFont {
	_ = width; _ = height;
	if (svg.type != .ttf) {
		return ZError.WrongAssetType;
	}

	var self = try ZFont.init();

	switch (svg.data) {
		.compile_time => |data| {
			_ = ft.FT_New_Memory_Face(root.freetype, data.ptr, @intCast(data.len), 0, &self.face);
		},
		.runtime => |data| {
			_ = ft.FT_New_Memory_Face(root.freetype, data.ptr, @intCast(data.len), 0, &self.face);
		}
	}
	_ = ft.FT_Set_Char_Size(self.face, 0, 1000, 96, 96);

	// based on:
	// https://gist.github.com/baines/b0f9e4be04ba4e6f56cab82eef5008ff

	const glyph_amount: usize = @intCast(self.face.*.num_glyphs);
	const max_dim: i32 = (1 + (@as(i32, @intCast(self.face.*.size.*.metrics.height)) >> 6)) * @as(i32, @intFromFloat(@ceil(@sqrt(@as(f32, @floatFromInt(glyph_amount))))));
	var tex_w: usize = 1;
	while (tex_w < max_dim) tex_w <<= 1;
	const tex_h = tex_w;

	self.texture.data = try root.allocator.alloc(u8, tex_w * tex_h);
	self.texture.w = @intCast(tex_w);
	self.texture.h = @intCast(tex_h);
	self.texture.format = .R;

	var pen_x: usize = 0;
	var pen_y: usize = 0;

	self.glyphs = try .initCapacity(root.allocator, glyph_amount);
	self.glyphs.appendNTimesAssumeCapacity(undefined, glyph_amount);

	var i: usize = 0;
	while (i < glyph_amount) : (i += 1) {
		_ = ft.FT_Load_Char(self.face, i, ft.FT_LOAD_RENDER | ft.FT_LOAD_FORCE_AUTOHINT | ft.FT_LOAD_TARGET_LIGHT);
		const bitmap = &self.face.*.glyph.*.bitmap;

		if (pen_x + @as(usize, @intCast(bitmap.width)) >= tex_w) {
			pen_x = 0;
			pen_y += ((@as(usize, @intCast(self.face.*.size.*.metrics.height)) >> 6) + 1);
		}

		var row: usize = 0;
		while (row < bitmap.rows) : (row += 1) {
			var col: usize = 0;
			while (col < bitmap.width) : (col += 1) {
				self.texture.data[(pen_y + row) * tex_w + (pen_x + col)] = bitmap.buffer[row * @as(usize, @intCast(bitmap.pitch)) + col];
			}
		}

		self.glyphs.items[i].x = @intCast(pen_x);
		self.glyphs.items[i].y = @intCast(pen_y);
		self.glyphs.items[i].w = @intCast(pen_x + @as(usize, @intCast(bitmap.width)));
		self.glyphs.items[i].h = @intCast(pen_y + @as(usize, @intCast(bitmap.pitch)));

		self.glyphs.items[i].bearing_x = @intCast(self.face.*.glyph.*.bitmap_left);
		self.glyphs.items[i].bearing_y = @intCast(self.face.*.glyph.*.bitmap_top);
		self.glyphs.items[i].advance = @intCast(self.face.*.glyph.*.advance.x >> 6);

		pen_x += @as(usize, @intCast(bitmap.width)) + 1;
	}

	const font = hb.hb_ft_font_create_referenced(@ptrCast(self.face));
	hb.hb_ft_font_set_funcs(font);

	return self;
}
