const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const widget = root.widget;
const ZColor = root.color.ZColor;
const types = root.types;

pub const ZIcon = struct {
	icon: []const u8 = "",
	resource: root.context.ResourceHandle = undefined,

	pub fn setIcon(self: *@This(), self_widget: *widget.ZWidget, icon: []const u8) !void {
		_ = self_widget;
		self.icon = icon;
	}
};

pub const ZIconFI = widget.ZWidgetFI{
	.init = initZIcon,
	.deinit = deinitZIcon,
	.enterTree = enterTreeZIcon,
	.exitTree = exitTreeZIcon,
	.render = renderZIcon,
};

fn initZIcon(self: *widget.ZWidget, context: *root.context.ZContext) callconv(.c) c_int {
	const data = context.allocator.create(ZIcon) catch return @intFromEnum(root.errors.ZErrorC.OutOfMemory);
	data.* = .{};
	self.type_name = @typeName(ZIcon);
	self.data = data;
	return 0;
}

fn deinitZIcon(self: *widget.ZWidget, context: *root.context.ZContext) callconv(.c) void {
	if (self.getData(ZIcon)) |data| {
		context.allocator.destroy(data);
		self.data = null;
	}
}

fn enterTreeZIcon(self: *widget.ZWidget) callconv(.c) void {
	if (self.getData(ZIcon)) |data| {
		const icon = root.assets.getAsset(data.icon) catch {
			return;
		};
		var bitmap = root.svg.svgToBitmap(self.window.?.context.allocator, icon, 256, 256) catch {
			return;
		};
		defer bitmap.deinit(self.window.?.context.allocator);
		data.resource = self.window.?.context.createTexture(&bitmap) catch {
			return;
		};
	}
}

fn exitTreeZIcon(self: *widget.ZWidget) callconv(.c) void {
	if (self.getData(ZIcon)) |data| {
		data.resource.deinit(self.window.?.context);
	}
}

fn renderZIcon(self: *widget.ZWidget, window: *root.tree.ZWidgetTree, commands: *root.context.RenderCommandList, area: ?*const types.ZBounds) callconv(.c) c_int {
	_ = area;
	if (self.getData(ZIcon)) |data| {
		const window_size = window.getBounds();

		const sizew = (self.clamped_bounds.w / window_size.w) * 2;
		const sizeh = (self.clamped_bounds.h / window_size.h) * 2;

		const posx = (self.clamped_bounds.x / window_size.w) * 2.0;
		const posy = (self.clamped_bounds.y / window_size.h) * 2.0;

		commands.append(
			window.context.getShader("bitmap") catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed),
			null,
			&[_]root.context.TextureParameter{
				.{
					.slot = 0,
					.texture = data.resource
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
		) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);
	}
	return 0;
}

pub fn zIcon(context: *root.context.ZContext) *ZIconBuilder {
	return ZIconBuilder.init(context) catch |e| {
		std.debug.panic("{}", .{e});
	};
}

pub const ZIconBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *widget.ZWidget,
	context: *root.context.ZContext,

	pub fn init(context: *root.context.ZContext) anyerror!*@This() {
		const self = try context.allocator.create(@This());

		self.widget = try widget.ZWidget.init(context, &ZIconFI);
		self.context = context;

		return self;
	}

	pub fn build(self: *@This()) *widget.ZWidget {
		const final = self.widget;
		self.context.allocator.destroy(self);
		return final;
	}

	pub fn icon(self: *@This(), i: []const u8) *@This() {
		if (self.widget.getData(ZIcon)) |data| {
			data.setIcon(self.widget, i) catch {};
		}
		return self;
	}
};
