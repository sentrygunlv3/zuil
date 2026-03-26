const std = @import("std");
const zuil = @import("zuilcore");
const BuilderMixin = zuil.widget.BuilderMixin;

const ZWidget = zuil.widget.ZWidget;
const ZColor = zuil.color.ZColor;
const types = zuil.types;

pub const ZContainer = struct {
	color: ZColor = .default,
	radius: f32 = 10,
	child: ?*ZWidget = null,

	super: ZWidget = .{.fi = &vtable},

	pub const vtable = ZWidget.VTable.generate(@This());

	pub fn init(context: *zuil.context.ZContext) !*@This() {
		const self = try context.allocator.create(@This());
		self.* = .{};
		return self;
	}

	pub fn deinit(widget: *ZWidget, context: *zuil.context.ZContext) void {
		const self: *@This() = widget.as(@This());

		if (self.child) |c| {
			c.exitTreeExceptParent(context);
			c.deinit(context);
		}
		context.allocator.destroy(self);
	}

	pub fn render(
		widget: *ZWidget,
		tree: *zuil.tree.ZWidgetTree,
		commands: *zuil.context.RenderCommandList,
		area: ?types.ZBounds
	) !void {
		const self: *@This() = widget.as(@This());

		block: {
			if (area) |a| {
				if (
					widget.clamped_bounds.x > a.x + a.w or
					widget.clamped_bounds.x + widget.clamped_bounds.w < a.x or
					widget.clamped_bounds.y > a.y + a.h or
					widget.clamped_bounds.y + widget.clamped_bounds.h < a.y
				) {
					break :block;
				}
			}

			const window_size = tree.getBounds();

			const sizew = (widget.clamped_bounds.w / window_size.w) * 2;
			const sizeh = (widget.clamped_bounds.h / window_size.h) * 2;

			const posx = (widget.clamped_bounds.x / window_size.w) * 2.0;
			const posy = (widget.clamped_bounds.y / window_size.h) * 2.0;

			try commands.append(
				try tree.context.getShader("container"),
				null,
				&[0]zuil.context.TextureParameter{},
				&[_]zuil.context.ShaderParameter{
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
						.name = "screenSize",
						.value = .{.uniform2f = .{
							.a = window_size.w,
							.b = window_size.h,
						}}
					},
					.{
						.name = "radius",
						.value = .{.uniform1f = self.radius}
					},
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

		if (self.child) |child| {
			try child.render(tree, commands, if (area != null) area.? else null);
		}
	}

	pub fn getChildren(widget: *ZWidget) ![]*ZWidget {
		const self: *@This() = widget.as(@This());

		if (self.child) |child| {
			var s = [_]*ZWidget{child};
			return &s;
		}
		return &[_]*ZWidget{};
	}

	pub fn removeChild(widget: *ZWidget, child: *ZWidget) !void {
		const self: *@This() = widget.as(@This());

		if (self.child == child) {
			self.child = null;
		}
		return zuil.ZError.NoChildFound;
	}
};

pub const ZContainerBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *ZContainer,
	context: *zuil.context.ZContext,

	pub fn init(context: *zuil.context.ZContext) anyerror!*@This() {
		const self = try context.allocator.create(@This());
		errdefer context.allocator.destroy(self);

		self.* = .{
			.widget = try ZContainer.init(context),
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

	pub fn radius(self: *@This(), new: f32) *@This() {
		self.widget.radius = new;
		return self;
	}

	pub fn child(self: *@This(), new: *ZWidget) *@This() {
		self.widget.child = new;
		self.widget.child.?.parent = &self.widget.super;
		self.widget.child.?.window = self.widget.super.window;

		return self;
	}
};
