const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const widget = root.zwidget;
const ZColor = root.color.ZColor;
const renderer = root.renderer;
const types = root.types;

pub const ZPosition = struct {
	x: f32 = 0,
	y: f32 = 0,
	absolute_size: bool = false,
	child: ?*widget.ZWidget = null,
};

pub const ZPositionFI = widget.ZWidgetFI{
	.init = initZPosition,
	.deinit = deinitZPosition,
	.getChildren = getChildrenZPosition,
	.removeChild = removeChildZPosition,
	.updateActualSize = updateActualSizeZPosition,
};

pub fn updateActualSizeZPosition(self: *widget.ZWidget, dirty: bool, w: f32, h: f32) callconv(.c) c_int {
	const margin = self.margin.asPixel(.{.w = w, .h = h}, self.window.?);
	const width = w - (margin.left + margin.right);
	const height = h - (margin.top + margin.bottom);
	if (dirty) {
		const size_max_w = self.size_max.w.asPixel(false, .{.w = width, .h = height}, self.window.?);
		const size_max_h = self.size_max.h.asPixel(true, .{.w = width, .h = height}, self.window.?);

		if (self.size.w == .percentage) {
			self.clamped_bounds.w = self.size.w.asPixel(false, .{.w = width, .h = height}, self.window.?);
		}
		if (self.size.h == .percentage) {
			self.clamped_bounds.h = self.size.h.asPixel(true, .{.w = width, .h = height}, self.window.?);
		}

		if (self.clamped_bounds.w > size_max_w) {
			self.clamped_bounds.w = size_max_w;
		}
		if (self.clamped_bounds.h > size_max_h) {
			self.clamped_bounds.h = size_max_h;
		}

		if (self.flags.keep_size_ratio) {
			if (width < height) {
				self.clamped_bounds.h = self.clamped_bounds.w / self.size_ratio;
			} else {
				self.clamped_bounds.w = self.clamped_bounds.h * self.size_ratio;
			}
		}
	}

	const children = self.getChildren() catch {
		return 0;
	};

	var space: root.types.ZBounds = .zero();
	if (self.getData(ZPosition)) |data| {
		if (data.absolute_size) {
			space = self.window.?.getBounds();
		} else {
			space = self.clamped_bounds;
		}
	}

	for (children) |child| {
		child.updateActualSize(
			dirty or child.flags.layout_dirty,
			space.w,
			space.h
		) catch return @intFromEnum(root.ZErrorC.updateActualSizeFailed);
	}
	return 0;
}

fn initZPosition(self: *widget.ZWidget) callconv(.c) c_int {
	const data = root.allocator.create(ZPosition) catch return @intFromEnum(root.ZErrorC.OutOfMemory);
	data.* = .{};
	self.type_name = @typeName(ZPosition);
	self.data = data;
	return 0;
}

fn deinitZPosition(self: *widget.ZWidget) callconv(.c) void {
	if (self.getData(ZPosition)) |data| {
		if (data.child) |c| {
			c.exitTreeExceptParent();
			c.deinit();
		}
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn getChildrenZPosition(self: *widget.ZWidget, return_len: *usize) callconv(.c) [*]*widget.ZWidget {
	if (self.getData(ZPosition)) |data| {
		if (data.child) |_| {
			return_len.* = 1;
			return @as([*]*widget.ZWidget, @ptrCast(&data.child.?))[0..1];
		}
	}
	return_len.* = 0;
	return &[0]*widget.ZWidget{};
}

fn removeChildZPosition(self: *widget.ZWidget, child: *widget.ZWidget) callconv(.c) c_int {
	if (self.getData(ZPosition)) |data| {
		if (data.child == child) {
			data.child = null;
		}
	}
	return 0;
}

pub fn zPosition() *ZPositionBuilder {
	return ZPositionBuilder.init() catch |e| {
		std.debug.panic("{}", .{e});
	};
}

pub const ZPositionBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *widget.ZWidget,

	pub fn init() anyerror!*@This() {
		const self = try root.allocator.create(@This());

		self.widget = try widget.ZWidget.init(&ZPositionFI);

		return self;
	}

	pub fn build(self: *@This()) *widget.ZWidget {
		const final = self.widget;
		root.allocator.destroy(self);
		return final;
	}

	pub fn position(self: *@This(), x: f32, y: f32) *@This() {
		if (self.widget.getData(ZPosition)) |data| {
			data.*.x = x;
			data.*.y = y;
		}
		return self;
	}

	pub fn absolute(self: *@This(), new: bool) *@This() {
		if (self.widget.getData(ZPosition)) |data| {
			data.*.absolute_size = new;
		}
		return self;
	}

	pub fn child(self: *@This(), c: *widget.ZWidget) *@This() {
		if (self.widget.getData(ZPosition)) |data| {
			data.child = c;
			data.child.?.parent = self.widget;
			data.child.?.window = self.widget.window;
		}
		return self;
	}
};
