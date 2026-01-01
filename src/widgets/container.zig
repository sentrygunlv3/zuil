const std = @import("std");
const root = @import("../root.zig");

const widget = root.zwidget;
const ZColor = root.color.ZColor;
const shader = root.shader;
const types = root.types;

pub fn zContainer() *ZContainerBuilder {
	return ZContainerBuilder.init() catch |e| {
		std.debug.panic("{}", .{e});
	};
}

pub const ZContainerFI = widget.ZWidgetFI{
	.init = initZContainer,
	.deinit = deinitZContainer,
	.render = renderZContainer,
	.getChildren = getChildrenZContainer,
};

fn initZContainer(self: *widget.ZWidget) anyerror!void {
	const data = try root.allocator.create(ZContainer);
	data.* = .{};
	self.type_name = @typeName(ZContainer);
	self.data = data;
}

fn deinitZContainer(self: *widget.ZWidget) void {
	if (self.getData(ZContainer)) |data| {
		if (data.child) |c| {
			c.destroy();
		}
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn renderZContainer(w: *widget.ZWidget, window: *root.ZWindow) anyerror!void {
	var color = ZColor.default();
	if (w.getData(ZContainer)) |data| {
		color = data.color;
	}

	const window_size = window.getBounds();

	const vertices = [_]f32{
		// bottom left
		0, -1,
		// bottom right
		1, -1,
		// top right
		1, 0,
		// top left
		0, 0,
	};

	const indices = [_]u32{
		0, 1, 2,
		0, 2, 3,
	};

	var vertex_arrays: u32 = 0;
	var buffers: u32 = 0;
	var element_buffer: u32 = 0;

	root.gl.genVertexArrays(1, &vertex_arrays);
	root.gl.genBuffers(1, &buffers);
	root.gl.genBuffers(1, &element_buffer);

	root.gl.bindVertexArray(vertex_arrays);

	root.gl.bindBuffer(root.gl.ARRAY_BUFFER, buffers);
	root.gl.bufferData(root.gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, root.gl.STATIC_DRAW);

	root.gl.bindBuffer(root.gl.ELEMENT_ARRAY_BUFFER, element_buffer);
	root.gl.bufferData(root.gl.ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, root.gl.STATIC_DRAW);

	root.gl.vertexAttribPointer(0, 2, root.gl.FLOAT, root.gl.FALSE, 2 * @sizeOf(f32), null);
	root.gl.enableVertexAttribArray(0);

	const program = try shader.getShader("container");
	root.gl.useProgram(program);

	const sizew = (w.clamped_bounds.w / window_size.w) * 2;
	const sizeh = (w.clamped_bounds.h / window_size.h) * 2;

	const posx = (w.clamped_bounds.x / window_size.w) * 2.0;
	const posy = (w.clamped_bounds.y / window_size.h) * 2.0;

	const position_loc = root.gl.getUniformLocation(program, "pos");
	root.gl.uniform2f(position_loc, posx, posy);

	const size_loc = root.gl.getUniformLocation(program, "size");
	root.gl.uniform2f(size_loc, sizew, sizeh);

	const color_loc = root.gl.getUniformLocation(program, "color");
	root.gl.uniform4f(color_loc, color.r, color.g, color.b, color.a);

	root.gl.drawElements(root.gl.TRIANGLES, 6, root.gl.UNSIGNED_INT, null);

	root.gl.deleteVertexArrays(1, &vertex_arrays);
	root.gl.deleteBuffers(1, &buffers);
	root.gl.deleteBuffers(1, &element_buffer);
	root.gl.bindVertexArray(0);

	if (w.getData(ZContainer)) |data| {
		if (data.child) |child| {
			try child.render(window);
		}
	}
}

fn getChildrenZContainer(self: *widget.ZWidget) []*widget.ZWidget {
	if (self.getData(ZContainer)) |data| {
		if (data.child) |_| {
			return @as([*]*widget.ZWidget, @ptrCast(&data.child.?))[0..1];
		}
	}
	return &[0]*widget.ZWidget{};
}

pub const ZContainerBuilder = struct {
	widget: *widget.ZWidget,

	pub fn init() anyerror!*@This() {
		const self = try root.allocator.create(@This());

		self.widget = try widget.ZWidget.init(&ZContainerFI);

		return self;
	}

	pub fn build(self: *@This()) *widget.ZWidget {
		const final = self.widget;
		root.allocator.destroy(self);
		return final;
	}

	pub fn size(self: *@This(), w: root.types.ZUnit, h: root.types.ZUnit) *@This() {
		self.widget.size = .{
			.w = w,
			.h = h
		};
		return self;
	}

	pub fn position(self: *@This(), x: root.types.ZUnit, y: root.types.ZUnit) *@This() {
		self.widget.position = .{
			.x = x,
			.y = y,
		};
		return self;
	}

	pub fn margin(self: *@This(), top: root.types.ZUnit, bottom: root.types.ZUnit, left: root.types.ZUnit, right: root.types.ZUnit) *@This() {
		self.widget.margin = .{
			.top = top,
			.bottom = bottom,
			.left = left,
			.right = right
		};
		return self;
	}

	pub fn content_align(self: *@This(), a: types.ZAlign) *@This() {
		self.widget.content_alignment = a;
		return self;
	}

	pub fn layout(self: *@This(), l: types.ZLayout) *@This() {
		self.widget.layout = l;
		return self;
	}

	pub fn eventCallback(self: *@This(), event: *const fn (self: *widget.ZWidget, event: root.input.ZEvent) anyerror!void) *@This() {
		self.widget.mutable_fi.event = event;
		return self;
	}

	pub fn color(self: *@This(), c: ZColor) *@This() {
		if (self.widget.getData(ZContainer)) |data| {
			data.*.color = c;
		}
		return self;
	}

	pub fn child(self: *@This(), c: *widget.ZWidget) *@This() {
		if (self.widget.getData(ZContainer)) |data| {
			data.child = c;
			data.child.?.parent = self.widget;
			data.child.?.window = self.widget.window;
		}
		return self;
	}
};

pub const ZContainer = struct {
	color: ZColor = ZColor.default(),
	child: ?*widget.ZWidget = null,
};
