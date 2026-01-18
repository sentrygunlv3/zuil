const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const widget = root.zwidget;
const ZColor = root.color.ZColor;
const shader = root.shader;
const renderer = root.renderer;
const types = root.types;

pub const ZContainer = struct {
	color: ZColor = ZColor.default(),
	child: ?*widget.ZWidget = null,
};

pub const ZContainerFI = widget.ZWidgetFI{
	.init = initZContainer,
	.deinit = deinitZContainer,
	.render = renderZContainer,
	.getChildren = getChildrenZContainer,
	.removeChild = removeChildZContainer,
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
			c.exitTreeExceptParent();
			c.deinit();
		}
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn renderZContainer(self: *widget.ZWidget, window: *root.ZWindow, commands: *root.renderer.RenderCommandList, area: ?types.ZBounds) anyerror!void {
	block: {
		if (area) |a| {
			if (
				self.clamped_bounds.x > a.x + a.w or
				self.clamped_bounds.x + self.clamped_bounds.w < a.x or
				self.clamped_bounds.y > a.y + a.h or
				self.clamped_bounds.y + self.clamped_bounds.h < a.y
			) {
				break :block;
			}
		}

		var color = ZColor.default();
		if (self.getData(ZContainer)) |data| {
			color = data.color;
		}

		const window_size = window.getBounds();

		const sizew = (self.clamped_bounds.w / window_size.w) * 2;
		const sizeh = (self.clamped_bounds.h / window_size.h) * 2;

		const posx = (self.clamped_bounds.x / window_size.w) * 2.0;
		const posy = (self.clamped_bounds.y / window_size.h) * 2.0;

		try commands.append(
			"container",
			&[_]renderer.ShaderParameter{
				.{
					.name = "pos",
					.value = .{.uniform2f = .{
						.a = posx,
						.b = posy,
					}}
				},
				.{
					.name = "size",
					.value = .{.uniform2f = .{
						.a = sizew,
						.b = sizeh,
					}}
				},
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
		);
	}

	if (self.getData(ZContainer)) |data| {
		if (data.child) |child| {
			try child.render(window, commands, area);
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

fn removeChildZContainer(self: *widget.ZWidget, child: *widget.ZWidget) anyerror!void {
	if (self.getData(ZContainer)) |data| {
		if (data.child == child) {
			data.child = null;
		}
	}
	return;
}

pub fn zContainer() *ZContainerBuilder {
	return ZContainerBuilder.init() catch |e| {
		std.debug.panic("{}", .{e});
	};
}

pub const ZContainerBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
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
