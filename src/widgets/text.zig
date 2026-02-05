const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const widget = root.widget;
const ZColor = root.color.ZColor;
const renderer = root.renderer;
const types = root.types;
const colors = root.color;

pub const ZText = struct {
	color: ZColor = ZColor.default(),
	text: []const u8 = "",
};

pub const ZTextFI = widget.ZWidgetFI{
	.init = init,
	.deinit = deinit,
	.render = render,
};

fn init(self: *widget.ZWidget) callconv(.c) c_int {
	const data = root.allocator.create(ZText) catch return @intFromEnum(root.errors.ZErrorC.OutOfMemory);
	data.* = .{};
	self.type_name = @typeName(ZText);
	self.data = data;
	return 0;
}

fn deinit(self: *widget.ZWidget) callconv(.c) void {
	if (self.getData(ZText)) |data| {
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn render(
	self: *widget.ZWidget,
	tree: *root.tree.ZWidgetTree,
	commands: *renderer.context.RenderCommandList,
	area: ?*const types.ZBounds
) callconv(.c) c_int {
	if (area) |a| {
		if (
			self.clamped_bounds.x > a.x + a.w or
			self.clamped_bounds.x + self.clamped_bounds.w < a.x or
			self.clamped_bounds.y > a.y + a.h or
			self.clamped_bounds.y + self.clamped_bounds.h < a.y
		) {
			return 0;
		}
	}

	var color = ZColor.default();
	var text: []const u8 = "";
	if (self.getData(ZText)) |data| {
		color = data.color;
		text = data.text;
	}

	const window_size = tree.getBounds();

	const sizew = 2 / window_size.w;
	const sizeh = 2 / window_size.h;

	const posx = (self.clamped_bounds.x / window_size.w) * 2 - 1;
	const posy = 1 - (self.clamped_bounds.y / window_size.h) * 2;

	const font = root.fonts.get("firesans") orelse return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);
	const texture = tree.context.getFontTexture(font) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);

	const buffer = root.hb.hb_buffer_create() orelse return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);
	defer root.hb.hb_buffer_destroy(buffer);
	root.hb.hb_buffer_reset(buffer);

	root.hb.hb_buffer_set_direction(buffer, root.hb.HB_DIRECTION_LTR);
	root.hb.hb_buffer_set_script(buffer, root.hb.HB_SCRIPT_LATIN);
	root.hb.hb_buffer_set_language(buffer, root.hb.hb_language_from_string("en", -1));

	root.hb.hb_buffer_add_utf8(buffer, text.ptr, @intCast(text.len), 0, @intCast(text.len));

	root.hb.hb_shape(
		font.hb_font,
		buffer,
		null,
		0
	);

	var count_c: c_uint = 0;
	const glyph_info = root.hb.hb_buffer_get_glyph_infos(buffer, &count_c);
	const glyph_pos = root.hb.hb_buffer_get_glyph_positions(buffer, &count_c);
	const count: u32 = @intCast(count_c);

	var mesh = root.mesh.ZMeshBuilder.init(root.allocator) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);
	defer mesh.deinit();

	const tex_w = @as(f32, @floatFromInt(font.texture.w));
	const tex_h = @as(f32, @floatFromInt(font.texture.h));

	var index: u32 = 0;
	var advance: f32 = 0;
	var i: usize = 0;
	while (i < count) : (i += 1) {
		const glyph = font.glyphs.get(glyph_info[i].codepoint) orelse continue;

		const x_offset = (@as(f32, @floatFromInt(glyph_pos[i].x_offset)) / 64) * sizew;
		const y_offset = (@as(f32, @floatFromInt(glyph_pos[i].y_offset)) / 64) * sizeh;

		const char_w = @as(f32, @floatFromInt(glyph.font_width)) * sizew;
		const char_h = @as(f32, @floatFromInt(glyph.font_height)) * sizeh;

		const pos0 = (advance + posx + x_offset) + @as(f32, @floatFromInt(glyph.font_bearing_x)) * sizew;
		const pos1 = (posy - char_h + y_offset) + @as(f32, @floatFromInt(glyph.font_bearing_y)) * sizeh;
		const pos2 = pos0 + char_w;
		const pos3 = pos1 + char_h;

		const uv0 = @as(f32, @floatFromInt(glyph.x)) / tex_w;
		const uv1 = @as(f32, @floatFromInt(glyph.y)) / tex_h;
		const uv2 = @as(f32, @floatFromInt(glyph.w)) / tex_w;
		const uv3 = @as(f32, @floatFromInt(glyph.h)) / tex_h;

		mesh.appendVertices(&[_]f32{
			pos0, pos1, uv0, uv3,
			pos0, pos3, uv0, uv1,
			pos2, pos3, uv2, uv1,
			pos2, pos1, uv2, uv3,
		}) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);
		mesh.appendIndices(&[_]u32{
			index, index + 1, index + 2,
			index, index + 2, index + 3,
		}) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);

		index += 4;
		advance += (@as(f32, @floatFromInt(glyph_pos[i].x_advance)) / 64) * sizew;
	}

	var mesh_handle = renderer.createMesh(&mesh.build()) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);
	renderer.resourceRemoveUser(&mesh_handle) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);

	commands.append(
		"font",
		mesh_handle,
		&[_]renderer.context.TextureParameter{
			.{
				.slot = 0,
				.texture = texture
			},
		},
		&[_]renderer.context.ShaderParameter{
			.{
				.name = "color",
				.value = .{.uniform4f = .{
					.a = color.r,
					.b = color.g,
					.c = color.b,
					.d = color.a,
				}}
			},
		},
	) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);

	return 0;
}

pub fn zText() *zTextBuilder {
	return zTextBuilder.init() catch |e| {
		std.debug.panic("{}", .{e});
	};
}

pub const zTextBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *widget.ZWidget,

	pub fn init() anyerror!*@This() {
		const self = try root.allocator.create(@This());

		self.widget = try widget.ZWidget.init(&ZTextFI);

		return self;
	}

	pub fn build(self: *@This()) *widget.ZWidget {
		const final = self.widget;
		root.allocator.destroy(self);
		return final;
	}

	pub fn color(self: *@This(), c: ZColor) *@This() {
		if (self.widget.getData(ZText)) |data| {
			data.*.color = c;
		}
		return self;
	}

	pub fn text(self: *@This(), t: []const u8) *@This() {
		if (self.widget.getData(ZText)) |data| {
			data.*.text = t;
		}
		return self;
	}
};
