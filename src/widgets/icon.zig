const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const widget = root.zwidget;
const ZColor = root.color.ZColor;
const renderer = root.renderer;
const types = root.types;

pub const ZIcon = struct {
	icon: []const u8 = "",
	resource: root.renderer.context.ResourceHandle = undefined,

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

fn initZIcon(self: *widget.ZWidget) callconv(.c) c_int {
	const data = root.allocator.create(ZIcon) catch return @intFromEnum(root.ZErrorC.OutOfMemory);
	data.* = .{};
	self.type_name = @typeName(ZIcon);
	self.data = data;
	return 0;
}

fn deinitZIcon(self: *widget.ZWidget) callconv(.c) void {
	if (self.getData(ZIcon)) |data| {
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn enterTreeZIcon(self: *widget.ZWidget) callconv(.c) void {
	if (self.getData(ZIcon)) |data| {
		const icon = root.assets.getAsset(data.icon) catch {
			return;
		};
		data.resource = root.renderer.createTexture(
			icon,
			256,
			256
		) catch {
			return;
		};
	}
}

fn exitTreeZIcon(self: *widget.ZWidget) callconv(.c) void {
	if (self.getData(ZIcon)) |data| {
		data.resource.deinit();
	}
}

fn renderZIcon(self: *widget.ZWidget, window: *root.ZWidgetTree, commands: *root.renderer.context.RenderCommandList, area: ?*const types.ZBounds) callconv(.c) c_int {
	_ = area;
	if (self.getData(ZIcon)) |data| {
		const window_size = window.getBounds();

		const sizew = (self.clamped_bounds.w / window_size.w) * 2;
		const sizeh = (self.clamped_bounds.h / window_size.h) * 2;

		const posx = (self.clamped_bounds.x / window_size.w) * 2.0;
		const posy = (self.clamped_bounds.y / window_size.h) * 2.0;

		commands.append(
			"bitmap",
			&[_]renderer.context.ShaderParameter{
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
					.value = .{.texture = &data.resource}
				},
			},
		) catch return @intFromEnum(root.ZErrorC.renderWidgetFailed);
	}
	return 0;
}

pub fn zIcon() *ZIconBuilder {
	return ZIconBuilder.init() catch |e| {
		std.debug.panic("{}", .{e});
	};
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
			data.setIcon(self.widget, i) catch {};
		}
		return self;
	}
};
