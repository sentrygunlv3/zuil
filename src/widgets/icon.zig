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
};

pub const ZIconFI = widget.ZWidgetFI{
	.init = initZIcon,
	.deinit = deinitZIcon,
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

fn renderZIcon(self: *widget.ZWidget, window: *root.ZWindow) anyerror!void {
	var icon: []const u8 = "";
	if (self.getData(ZIcon)) |data| {
		icon = data.icon;
	}

	const window_size = window.getBounds();

	var texture: u32 = 0;

	const image = try root.assets.getAsset(icon);
	const bitmap = try root.svg.svgToBitmap(image, @intFromFloat(self.clamped_bounds.w), @intFromFloat(self.clamped_bounds.h));

	root.gl.genTextures(1, &texture);
	root.gl.activeTexture(root.gl.TEXTURE0);
	root.gl.bindTexture(root.gl.TEXTURE_2D, texture);
	root.gl.texParameteri(root.gl.TEXTURE_2D, root.gl.TEXTURE_MIN_FILTER, root.gl.NEAREST);
	root.gl.texParameteri(root.gl.TEXTURE_2D, root.gl.TEXTURE_MAG_FILTER, root.gl.NEAREST);
	root.gl.texImage2D(
		root.gl.TEXTURE_2D,
		0,
		root.gl.RGBA,
		@intCast(bitmap.w),
		@intCast(bitmap.h),
		0,
		root.gl.BGRA,
		root.gl.UNSIGNED_BYTE,
		bitmap.data.ptr
	);
	defer root.gl.deleteTextures(1, &texture);

	const sizew = (self.clamped_bounds.w / window_size.w) * 2;
	const sizeh = (self.clamped_bounds.h / window_size.h) * 2;

	const posx = (self.clamped_bounds.x / window_size.w) * 2.0;
	const posy = (self.clamped_bounds.y / window_size.h) * 2.0;

	try renderer.renderCommand(.{
		.shader = try shader.getShader("bitmap"),
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
				.value = .{.uniform1i = @intCast(texture)}
			},
		},
	});
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
			data.icon = i;
		}
		return self;
	}
};
