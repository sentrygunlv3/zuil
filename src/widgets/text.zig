const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const ZWidget = root.widget.ZWidget;
const ZColor = root.color.ZColor;
const types = root.types;
const colors = root.color;

pub const ZText = struct {
	color: ZColor = ZColor.default,
	text: []const u8 = "",
	font_size: u32 = 14,

	super: ZWidget = .{.fi = &vtable},

	pub const vtable = ZWidget.VTable.generate(@This());

	pub fn init(context: *root.context.ZContext) !*@This() {
		const self = try context.allocator.create(@This());
		self.* = .{};
		return self;
	}

	pub fn deinit(widget: *ZWidget, context: *root.context.ZContext) void {
		const self: *@This() = widget.as(@This());

		context.allocator.destroy(self);
	}

	// very basic text thing
	// probably needs a complety rewrite to work with more advanced stuff
	pub fn render(
		widget: *ZWidget,
		tree: *root.tree.ZWidgetTree,
		commands: *root.context.RenderCommandList,
		area: ?types.ZBounds
	) !void {
		const self: *@This() = widget.as(@This());

		if (area) |a| {
			if (
				widget.clamped_bounds.x > a.x + a.w or
				widget.clamped_bounds.x + widget.clamped_bounds.w < a.x or
				widget.clamped_bounds.y > a.y + a.h or
				widget.clamped_bounds.y + widget.clamped_bounds.h < a.y
			) {
				return;
			}
		}

		const font = tree.context.fonts.get("firesans") orelse return;
		const texture = try tree.context.getFontTexture(tree.context, font);

		const window_size = tree.getBounds();

		const sizew = 2 / window_size.w;
		const sizeh = 2 / window_size.h;

		const widgetx = (widget.clamped_bounds.x / window_size.w) * 2 - 1;
		const widgety = 1 - (widget.clamped_bounds.y / window_size.h) * 2;
		//const widgetw = (self.clamped_bounds.w / window_size.w) * 2 - 1;
		//const widgeth = 1 - (self.clamped_bounds.h / window_size.h) * 2;

		const sub_font = root.hb.hb_font_create_sub_font(font.hb_font);
		defer root.hb.hb_font_destroy(sub_font);
		root.hb.hb_font_set_scale(sub_font, @intCast(self.font_size * 64), @intCast(self.font_size * 64));

		const buffer = root.hb.hb_buffer_create();
		defer root.hb.hb_buffer_destroy(buffer);
		root.hb.hb_buffer_reset(buffer);

		root.hb.hb_buffer_set_direction(buffer, root.hb.HB_DIRECTION_LTR);
		root.hb.hb_buffer_set_script(buffer, root.hb.HB_SCRIPT_LATIN);
		root.hb.hb_buffer_set_language(buffer, root.hb.hb_language_from_string("en", -1));

		root.hb.hb_buffer_add_utf8(buffer, self.text.ptr, @intCast(self.text.len), 0, @intCast(self.text.len));

		root.hb.hb_shape(
			sub_font,
			buffer,
			null,
			0
		);

		var count_c: c_uint = 0;
		const glyph_info = root.hb.hb_buffer_get_glyph_infos(buffer, &count_c);
		const glyph_pos = root.hb.hb_buffer_get_glyph_positions(buffer, &count_c);
		const count: u32 = @intCast(count_c);

		var mesh = try root.mesh.ZMeshBuilder.init(widget.window.?.context.allocator);
		defer mesh.deinit();

		const scale = @as(f32, @floatFromInt(self.font_size)) / 96;

		const tex_w = @as(f32, @floatFromInt(font.texture.w));
		const tex_h = @as(f32, @floatFromInt(font.texture.h));

		const line_height = (@as(f32, @floatFromInt(font.face.*.size.*.metrics.height)) / 64) * sizeh * scale;

		const posx = widgetx;
		const posy = widgety - line_height / 2;

		var index: u32 = 0;
		var advance: f32 = 0;
		var i: usize = 0;
		while (i < count) : (i += 1) {
			const glyph = font.glyphs.get(glyph_info[i].codepoint) orelse continue;

			const x_offset = (@as(f32, @floatFromInt(glyph_pos[i].x_offset)) / 64) * sizew;
			const y_offset = (@as(f32, @floatFromInt(glyph_pos[i].y_offset)) / 64) * sizeh;

			const char_w = @as(f32, @floatFromInt(glyph.font_width)) * sizew * scale;
			const char_h = @as(f32, @floatFromInt(glyph.font_height)) * sizeh * scale;

			const pos0 = (advance + posx + x_offset) + @as(f32, @floatFromInt(glyph.font_bearing_x)) * sizew * scale;
			const pos1 = (posy - char_h + y_offset) + @as(f32, @floatFromInt(glyph.font_bearing_y)) * sizeh * scale;
			const pos2 = pos0 + char_w;
			const pos3 = pos1 + char_h;

			const uv0 = @as(f32, @floatFromInt(glyph.x)) / tex_w;
			const uv1 = @as(f32, @floatFromInt(glyph.y)) / tex_h;
			const uv2 = @as(f32, @floatFromInt(glyph.w)) / tex_w;
			const uv3 = @as(f32, @floatFromInt(glyph.h)) / tex_h;

			try mesh.appendVertices(&[_]f32{
				pos0, pos1, uv0, uv3,
				pos0, pos3, uv0, uv1,
				pos2, pos3, uv2, uv1,
				pos2, pos1, uv2, uv3,
			});
			try mesh.appendIndices(&[_]u32{
				index, index + 1, index + 2,
				index, index + 2, index + 3,
			});

			index += 4;
			advance += (@as(f32, @floatFromInt(glyph_pos[i].x_advance)) / 64) * sizew;
		}

		var mesh_handle = try tree.context.createMesh(&mesh.build());
		try tree.context.resourceRemoveUser(&mesh_handle);

		try commands.append(
			try tree.context.getShader("font"),
			mesh_handle,
			&[_]root.context.TextureParameter{
				.{
					.slot = 0,
					.texture = texture
				},
			},
			&[_]root.context.ShaderParameter{
				.{
					.name = "color",
					.value = .{.uniform4f = .{
						.a = self.color.r,
						.b = self.color.g,
						.c = self.color.b,
						.d = self.color.a,
					}}
				},
			},
		);
	}
};

pub const zTextBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *ZText,
	context: *root.context.ZContext,

	pub fn init(context: *root.context.ZContext) anyerror!*@This() {
		const self = try context.allocator.create(@This());
		errdefer context.allocator.destroy(self);

		self.* = .{
			.widget = try ZText.init(context),
			.context = context,
		};

		return self;
	}

	pub fn build(self: *@This()) *ZWidget {
		const final = &self.widget.super;
		self.context.allocator.destroy(self);
		return final;
	}

	pub fn color(self: *@This(), new: ZColor) *@This() {
		self.widget.color = new;
		return self;
	}

	pub fn text(self: *@This(), new: []const u8) *@This() {
		self.widget.text = new;
		return self;
	}

	pub fn fontSize(self: *@This(), new: u32) *@This() {
		self.widget.font_size = new;
		return self;
	}
};
