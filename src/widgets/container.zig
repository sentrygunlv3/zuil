const std = @import("std");
const root = @import("../root.zig");

const widget = root.uwidget;
const UColor = root.color.UColor;
const shader = root.shader;
const types = root.types;

pub fn uContainer() *UContainerBuilder {
	return UContainerBuilder.init() catch |e| {
		std.log.err("{}", .{e});
		std.process.exit(1);
		unreachable;
	};
}

pub const UContainerFI = widget.UWidgetFI{
	.init = initUContainer,
	.deinit = deinitUContainer,
	.render = renderUContainer,
	.getChildren = getChildrenUContainer,
};

fn initUContainer(self: *widget.UWidget) anyerror!void {
	self.type_name = "UContainer";
	const data = try root.allocator.create(UContainerData);
	data.* = UContainerData{};
	self.data = data;
}

fn deinitUContainer(self: *widget.UWidget) void {
	if (getData(self)) |data| {
		if (data.child) |c| {
			c.destroy();
		}
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn renderUContainer(w: *widget.UWidget, window: *root.UWindow) anyerror!void {
	var color = UColor.default();
	if (getData(w)) |data| {
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

	if (getData(w)) |data| {
		if (data.child) |child| {
			try child.render(window);
		}
	}
}

fn getChildrenUContainer(self: *widget.UWidget) []*widget.UWidget {
	if (getData(self)) |data| {
		if (data.child) |_| {
			return @as([*]*widget.UWidget, @ptrCast(&data.child.?))[0..1];
		}
	}
	return &[0]*widget.UWidget{};
}

pub const UContainerBuilder = struct {
	widget: *widget.UWidget,

	pub fn init() anyerror!*@This() {
		const self = try root.allocator.create(@This());

		self.widget = try widget.UWidget.init(UContainerFI);

		return self;
	}

	pub fn build(self: *@This()) *widget.UWidget {
		const final = self.widget;
		root.allocator.destroy(self);
		return final;
	}

	pub fn bounds(self: *@This(), x: f32, y: f32, w: f32, h: f32) *@This() {
		self.widget.bounds = .{
			.x = x,
			.y = y,
			.w = w,
			.h = h
		};
		return self;
	}

	pub fn margin(self: *@This(), top: f32, bottom: f32, left: f32, right: f32) *@This() {
		self.widget.margin = .{
			.top = top,
			.bottom = bottom,
			.left = left,
			.right = right
		};
		return self;
	}

	pub fn color(self: *@This(), c: UColor) *@This() {
		if (getData(self.widget)) |data| {
			data.*.color = c;
		}
		return self;
	}

	pub fn content_align(self: *@This(), a: types.UAlign) *@This() {
		self.widget.content_alignment = a;
		return self;
	}

	pub fn layout(self: *@This(), l: types.ULayout) *@This() {
		self.widget.layout = l;
		return self;
	}

	pub fn child(self: *@This(), c: *widget.UWidget) *@This() {
		if (getData(self.widget)) |data| {
			data.child = c;
			data.child.?.parent = self.widget;
			data.child.?.window = self.widget.window;
		}
		return self;
	}
};

pub const UContainerData = struct {
	color: UColor = UColor.default(),
	child: ?*widget.UWidget = null,
};

fn getData(self: *widget.UWidget) ?*UContainerData {
	if (self.data) |d| {
		return @ptrCast(@alignCast(d));
	}
	return null;
}
