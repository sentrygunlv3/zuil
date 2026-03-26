const std = @import("std");
const zuil = @import("zuilcore");
const BuilderMixin = zuil.widget.BuilderMixin;

const ZWidget = zuil.widget.ZWidget;
const ZColor = zuil.color.ZColor;
const types = zuil.types;

pub const ZIcon = struct {
	icon: []const u8 = "",
	resource: zuil.context.ResourceHandle = undefined,

	super: ZWidget = .{.fi = &vtable},

	pub const vtable = ZWidget.VTable.generate(@This());

	pub fn init(context: *zuil.context.ZContext) !*@This() {
		const self = try context.allocator.create(@This());
		self.* = .{};
		return self;
	}

	pub fn deinit(widget: *ZWidget, context: *zuil.context.ZContext) void {
		const self: *@This() = widget.as(@This());

		context.allocator.destroy(self);
	}

	pub fn enterTree(widget: *ZWidget) void {
		const self: *@This() = widget.as(@This());

		const icon = zuil.assets.getAsset(self.icon) catch {
			return;
		};
		var bitmap = zuil.svg.svgToBitmap(widget.window.?.context.allocator, icon, 256, 256) catch {
			return;
		};
		defer bitmap.deinit(widget.window.?.context.allocator);
		self.resource = widget.window.?.context.createTexture(&bitmap) catch {
			return;
		};
	}

	pub fn exitTree(widget: *ZWidget, context: *zuil.context.ZContext) void {
		const self: *@This() = widget.as(@This());

		self.resource.deinit(context);
	}

	pub fn render(
		widget: *ZWidget,
		tree: *zuil.tree.ZWidgetTree,
		commands: *zuil.context.RenderCommandList,
		area: ?types.ZBounds
	) !void {
		const self: *@This() = widget.as(@This());
		_ = area;

		const window_size = tree.getBounds();

		const sizew = (widget.clamped_bounds.w / window_size.w) * 2;
		const sizeh = (widget.clamped_bounds.h / window_size.h) * 2;

		const posx = (widget.clamped_bounds.x / window_size.w) * 2.0;
		const posy = (widget.clamped_bounds.y / window_size.h) * 2.0;

		try commands.append(
			try tree.context.getShader("bitmap"),
			null,
			&[_]zuil.context.TextureParameter{
				.{
					.slot = 0,
					.texture = self.resource
				},
			},
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
			},
		);
	}

	pub fn setIcon(self: *@This(), icon: []const u8) !void {
		self.icon = icon;
	}
};

pub const ZIconBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *ZIcon,
	context: *zuil.context.ZContext,

	pub fn init(context: *zuil.context.ZContext) anyerror!*@This() {
		const self = try context.allocator.create(@This());
		errdefer context.allocator.destroy(self);

		self.* = .{
			.widget = try ZIcon.init(context),
			.context = context,
		};

		return self;
	}

	pub fn build(self: *@This()) *ZWidget {
		const final = &self.widget.super;
		self.context.allocator.destroy(self);
		return final;
	}

	pub fn icon(self: *@This(), new: []const u8) *@This() {
		self.widget.setIcon(new) catch {};
		return self;
	}
};
