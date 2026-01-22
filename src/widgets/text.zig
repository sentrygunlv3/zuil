const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const widget = root.widget;
const ZColor = root.color.ZColor;
const renderer = root.renderer;
const types = root.types;

pub const ZText = struct {
	color: ZColor = ZColor.default(),
};

pub const ZTextFI = widget.ZWidgetFI{
	.init = init,
	.deinit = deinit,
	.render = render,
};

fn init(self: *widget.ZWidget) callconv(.c) c_int {
	const data = root.allocator.create(ZText) catch return @intFromEnum(root.errors.ZErrorC.OutOfMemory);
	data.* = .{};
	self.type_name = @typeName(ZText);
	self.data = data;
	return 0;
}

fn deinit(self: *widget.ZWidget) callconv(.c) void {
	if (self.getData(ZText)) |data| {
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn render(
	self: *widget.ZWidget,
	tree: *root.tree.ZWidgetTree,
	commands: *renderer.context.RenderCommandList,
	area: ?*const types.ZBounds
) callconv(.c) c_int {
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

		const font = root.fonts.get("firesans");
		if (font == null) return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);
		const texture = tree.context.getFontTexture(font.?) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);

		const window_size = tree.getBounds();

		const sizew = (self.clamped_bounds.w / window_size.w) * 2;
		const sizeh = (self.clamped_bounds.h / window_size.h) * 2;

		const posx = (self.clamped_bounds.x / window_size.w) * 2;
		const posy = (self.clamped_bounds.y / window_size.h) * 2;

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
					.value = .{.texture = texture}
				},
			},
		) catch return @intFromEnum(root.errors.ZErrorC.renderWidgetFailed);
	}
	return 0;
}

pub fn zText() *zTextBuilder {
	return zTextBuilder.init() catch |e| {
		std.debug.panic("{}", .{e});
	};
}

pub const zTextBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *widget.ZWidget,

	pub fn init() anyerror!*@This() {
		const self = try root.allocator.create(@This());

		self.widget = try widget.ZWidget.init(&ZTextFI);

		return self;
	}

	pub fn build(self: *@This()) *widget.ZWidget {
		const final = self.widget;
		root.allocator.destroy(self);
		return final;
	}
};
