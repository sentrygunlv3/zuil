const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const widget = root.zwidget;
const ZColor = root.color.ZColor;
const shader = root.shader;
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

fn enterTreeZIcon(self: *widget.ZWidget) void {
	if (self.getData(ZIcon)) |data| {
		const icon = root.assets.getAsset(data.icon) catch {
			return;
		};
		data.resource = self.window.?.context.createTexture(
			icon,
			256,
			256
		) catch {
			return;
		};
	}
}

fn exitTreeZIcon(self: *widget.ZWidget) void {
	if (self.getData(ZIcon)) |data| {
		data.resource.deinit();
	}
}

fn renderZIcon(self: *widget.ZWidget, window: *root.ZWindow) anyerror!void {
	if (self.getData(ZIcon)) |data| {
		const window_size = window.getBounds();

		const sizew = (self.clamped_bounds.w / window_size.w) * 2;
		const sizeh = (self.clamped_bounds.h / window_size.h) * 2;

		const posx = (self.clamped_bounds.x / window_size.w) * 2.0;
		const posy = (self.clamped_bounds.y / window_size.h) * 2.0;

		try renderer.renderCommand(self.window.?.context, .{
			.shader = try shader.getShader(self.window.?.context, "bitmap"),
			.parameters = &[_]renderer.ShaderParameter{
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
		});
	}
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
