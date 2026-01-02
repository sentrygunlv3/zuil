const std = @import("std");
const root = @import("../../root.zig");
const BuilderMixin = @import("../builder.zig").BuilderMixin;

const widget = root.zwidget;
const ZColor = root.color.ZColor;
const shader = root.shader;
const types = root.types;

pub fn zIcon() *ZIconBuilder {
	return ZIconBuilder.init() catch |e| {
		std.debug.panic("{}", .{e});
	};
}

pub const ZIconFI = widget.ZWidgetFI{
	.init = initZIcon,
	.deinit = deinitZIcon,
	.render = renderZIcon,
};

fn initZIcon(self: *widget.ZWidget) anyerror!void {
	const data = try root.allocator.create(ZIcon);
	data.* = .{};
	self.type_name = @typeName(ZIcon);
	self.data = data;
}

fn deinitZIcon(self: *widget.ZWidget) void {
	if (self.getData(ZIcon)) |data| {
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn renderZIcon(w: *widget.ZWidget, window: *root.ZWindow) anyerror!void {
	var icon: []const u8 = "";
	if (w.getData(ZIcon)) |data| {
		icon = data.icon;
	}

	const window_size = window.getBounds();

	const vertices = [_]f32{
		// bottom left
		0, -1, 0, 1,
		// bottom right
		1, -1, 1, 1,
		// top right
		1, 0, 1, 0,
		// top left
		0, 0, 0, 0,
	};

	const indices = [_]u32{
		0, 1, 2,
		0, 2, 3,
	};

	var vertex_arrays: u32 = 0;
	var buffers: u32 = 0;
	var element_buffer: u32 = 0;
	var texture: u32 = 0;

	root.gl.genVertexArrays(1, &vertex_arrays);
	root.gl.genBuffers(1, &buffers);
	root.gl.genBuffers(1, &element_buffer);
	root.gl.genTextures(1, &texture);

	root.gl.activeTexture(root.gl.TEXTURE0);
	root.gl.bindTexture(root.gl.TEXTURE_2D, texture);
	root.gl.texParameteri(root.gl.TEXTURE_2D, root.gl.TEXTURE_MIN_FILTER, root.gl.NEAREST);
	root.gl.texParameteri(root.gl.TEXTURE_2D, root.gl.TEXTURE_MAG_FILTER, root.gl.NEAREST);

	const image = try root.assets.getAsset(icon);
	const bitmap = try root.svg.svgToBitmap(image, @intFromFloat(w.clamped_bounds.w), @intFromFloat(w.clamped_bounds.h));

	root.gl.texImage2D(
		root.gl.TEXTURE_2D,
		0,
		root.gl.RGBA,
		@intCast(bitmap.w),
		@intCast(bitmap.h),
		0,
		root.gl.BGRA,
		root.gl.UNSIGNED_BYTE,
		bitmap.data.ptr
	);

	root.gl.bindVertexArray(vertex_arrays);

	root.gl.bindBuffer(root.gl.ARRAY_BUFFER, buffers);
	root.gl.bufferData(root.gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, root.gl.STATIC_DRAW);

	root.gl.bindBuffer(root.gl.ELEMENT_ARRAY_BUFFER, element_buffer);
	root.gl.bufferData(root.gl.ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, root.gl.STATIC_DRAW);

	root.gl.vertexAttribPointer(0, 2, root.gl.FLOAT, root.gl.FALSE, 4 * @sizeOf(f32), null);
	root.gl.enableVertexAttribArray(0);

	root.gl.vertexAttribPointer(2, 2, root.gl.FLOAT, root.gl.FALSE, 4 * @sizeOf(f32), null);
	root.gl.enableVertexAttribArray(2);

	const program = try shader.getShader("bitmap");
	root.gl.useProgram(program);

	const sizew = (w.clamped_bounds.w / window_size.w) * 2;
	const sizeh = (w.clamped_bounds.h / window_size.h) * 2;

	const posx = (w.clamped_bounds.x / window_size.w) * 2.0;
	const posy = (w.clamped_bounds.y / window_size.h) * 2.0;

	const position_loc = root.gl.getUniformLocation(program, "pos");
	root.gl.uniform2f(position_loc, posx, posy);

	const size_loc = root.gl.getUniformLocation(program, "size");
	root.gl.uniform2f(size_loc, sizew, sizeh);

	const tex_loc = root.gl.getUniformLocation(program, "tex0");
	root.gl.uniform1i(tex_loc, 0);

	root.gl.enable(root.gl.BLEND);
	root.gl.blendFunc(root.gl.SRC_ALPHA, root.gl.ONE_MINUS_SRC_ALPHA);

	root.gl.drawElements(root.gl.TRIANGLES, 6, root.gl.UNSIGNED_INT, null);

	root.gl.deleteVertexArrays(1, &vertex_arrays);
	root.gl.deleteBuffers(1, &buffers);
	root.gl.deleteBuffers(1, &element_buffer);
	root.gl.deleteTextures(1, &texture);
	root.gl.bindVertexArray(0);
}

pub const ZIconBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *widget.ZWidget,

	pub fn init() anyerror!*@This() {
		const self = try root.allocator.create(@This());

		self.widget = try widget.ZWidget.init(&ZIconFI);

		return self;
	}

	pub fn build(self: *@This()) *widget.ZWidget {
		const final = self.widget;
		root.allocator.destroy(self);
		return final;
	}

	pub fn icon(self: *@This(), i: []const u8) *@This() {
		if (self.widget.getData(ZIcon)) |data| {
			data.icon = i;
		}
		return self;
	}
};

pub const ZIcon = struct {
	icon: []const u8 = "",
};
