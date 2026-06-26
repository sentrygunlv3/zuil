const std = @import("std");
const zuil = @import("zuilcore");
const root = @import("../root.zig");
const BuilderMixin = zuil.widget.BuilderMixin;

const ZWidget = zuil.widget.ZWidget;
const ZColor = zuil.color.ZColor;
const types = zuil.types;

pub const ZButton = struct {
	color: root.ContainerColor = .button,
	color_hover: root.ContainerColor = .none,
	radius: ?f32 = null,
	child: ?*ZWidget = null,
	hovered: bool = false,

	on_click: ?*const fn (self: *@This(), event: zuil.input.ZMouseEvent) void = null,

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
			c.deinit(context);
		}
		context.allocator.destroy(self);
	}

	pub fn render(
		widget: *ZWidget,
		tree: *zuil.tree.ZWidgetTree,
		area: ?types.ZBounds
	) !void {
		const self: *@This() = widget.as(@This());

		block: {
			const Style = root.Style;
			const s = tree.context.theme.get(@typeName(Style)) orelse {
				tree.context.log(.err, "style \"{s}\" not found in theme", .{@typeName(Style)});
				break :block;
			};
			const style: *Style = @ptrCast(@alignCast(s));

			const color = if (self.hovered and self.color_hover != .none)
				self.color_hover.get(style, self.hovered) else
				self.color.get(style, self.hovered);

			if (color.a == 0) break :block;

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

			try tree.painter.addCommand(
				tree.context.allocator,
				.container,
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
						.value = .{.uniform1f = self.radius orelse style.surface.radius}
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

		if (self.child) |child| {
			try child.render(tree, if (area != null) area.? else null);
		}
	}

	pub fn getChildren(widget: *ZWidget) ?[]*ZWidget {
		const self: *@This() = widget.as(@This());

		if (self.child != null) {
			return (&self.child.?)[0..1];
		}
		return null;
	}

	pub fn removeChild(widget: *ZWidget, child: *ZWidget) !void {
		const self: *@This() = widget.as(@This());

		if (self.child == child) {
			self.child = null;
		}
		return zuil.ZError.NoChildFound;
	}

	pub fn event(widget: *ZWidget, e: zuil.input.ZEvent) void {
		const self: *@This() = widget.as(@This());

		switch (e) {
			.mouse => {
				if (self.on_click) |func| {
					func(self, e.mouse);
				}
			},
			.mouse_move => |move| {
				if (self.hovered != move.entered) {
					self.hovered = move.entered;
					self.super.markDirtyRender();
				}
			},
			else => {}
		}
	}
};

pub const ZButtonBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *ZButton,
	context: *zuil.context.ZContext,

	pub fn init(context: *zuil.context.ZContext) anyerror!*@This() {
		const self = try context.allocator.create(@This());
		errdefer context.allocator.destroy(self);

		self.* = .{
			.widget = try ZButton.init(context),
			.context = context,
		};

		return self;
	}

	pub fn build(self: *@This()) *ZWidget {
		const final = &self.widget.super;
		self.context.allocator.destroy(self);
		return final;
	}

	pub fn color(self: *@This(), new: root.ContainerColor) *@This() {
		self.widget.color = new;
		return self;
	}

	pub fn colorHover(self: *@This(), new: root.ContainerColor) *@This() {
		self.widget.color_hover = new;
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

	pub fn setOnClick(self: *@This(), new: ?*const fn (self: *ZButton, event: zuil.input.ZMouseEvent) void) *@This() {
		self.widget.on_click = new;

		return self;
	}
};
