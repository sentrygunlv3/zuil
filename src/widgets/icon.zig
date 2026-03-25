const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const ZWidget = root.widget.ZWidget;
const ZColor = root.color.ZColor;
const types = root.types;

pub const ZIcon = struct {
	icon: []const u8 = "",
	resource: root.context.ResourceHandle = undefined,

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

	pub fn enterTree(widget: *ZWidget) void {
		const self: *@This() = widget.as(@This());

		const icon = root.assets.getAsset(self.icon) catch {
			return;
		};
		var bitmap = root.svg.svgToBitmap(widget.window.?.context.allocator, icon, 256, 256) catch {
			return;
		};
		defer bitmap.deinit(widget.window.?.context.allocator);
		self.resource = widget.window.?.context.createTexture(&bitmap) catch {
			return;
		};
	}

	pub fn exitTree(widget: *ZWidget, context: *root.context.ZContext) void {
		const self: *@This() = widget.as(@This());

		self.resource.deinit(context);
	}

	pub fn render(
		widget: *ZWidget,
		tree: *root.tree.ZWidgetTree,
		commands: *root.context.RenderCommandList,
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
			&[_]root.context.TextureParameter{
				.{
					.slot = 0,
					.texture = self.resource
				},
			},
			&[_]root.context.ShaderParameter{
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
	context: *root.context.ZContext,

	pub fn init(context: *root.context.ZContext) anyerror!*@This() {
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
