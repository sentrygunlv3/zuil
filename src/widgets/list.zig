const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const widget = root.widget;
const ZColor = root.color.ZColor;
const types = root.types;

pub const ZList = struct {
	direction: types.ZDirection = types.ZDirection.default(),
	spacing: f32 = 0,
	children: std.ArrayList(*widget.ZWidget) = undefined,
};

pub const ZListFI = widget.ZWidgetFI{
	.init = initZList,
	.deinit = deinitZList,
	.getChildren = getChildrenZList,
	.removeChild = removeChildZList,
	.updateActualSize = updateActualSizeZList,
	.updatePosition = updatePositionZList,
};

pub fn updateActualSizeZList(self: *widget.ZWidget, dirty: bool, w: f32, h: f32) callconv(.c) c_int {
	if (dirty) {
		const size_max_w = self.size_max.w.asPixel(false, .{.w = w, .h = h}, self.window.?);
		const size_max_h = self.size_max.h.asPixel(true, .{.w = w, .h = h}, self.window.?);

		if (self.size.w == .percentage) {
			self.clamped_bounds.w = self.size.w.asPixel(false, .{.w = w, .h = h}, self.window.?);
		}
		if (self.size.h == .percentage) {
			self.clamped_bounds.h = self.size.h.asPixel(true, .{.w = w, .h = h}, self.window.?);
		}

		if (self.clamped_bounds.w > size_max_w) {
			self.clamped_bounds.w = size_max_w;
		}
		if (self.clamped_bounds.h > size_max_h) {
			self.clamped_bounds.h = size_max_h;
		}
	}

	const children = self.getChildren() catch {
		return 0;
	};

	var new_space = self.clamped_bounds;
	var child_layout_dirty = true;

	if (!dirty) {
		child_layout_dirty = false;
		for (children) |child| {
			if (child.flags.layout_dirty) {
				child_layout_dirty = true;
				break;
			}
		}
	}

	if (!child_layout_dirty) {
		for (children) |child| {
			child.updateActualSize(
				false,
				self.clamped_bounds.w,
				self.clamped_bounds.h
			) catch return @intFromEnum(root.errors.ZErrorC.updateActualSizeFailed);
		}
		return 0;
	}

	if (self.getData(ZList)) |data| {
		switch (data.direction) {
			.horizontal => {
				for (children) |child| {
					child.updateActualSize(
						dirty or child.flags.layout_dirty,
						if (child.clamped_bounds.w > new_space.w or child.size.w == .percentage) new_space.w else child.clamped_bounds.w,
						new_space.h
					) catch return @intFromEnum(root.errors.ZErrorC.updateActualSizeFailed);
					new_space.w -= child.clamped_bounds.w;
				}
			},
			.vertical => {
				for (children) |child| {
					child.updateActualSize(
						dirty or child.flags.layout_dirty,
						new_space.w,
						if (child.clamped_bounds.h > new_space.h or child.size.h == .percentage) new_space.h else child.clamped_bounds.h
					) catch return @intFromEnum(root.errors.ZErrorC.updateActualSizeFailed);
					new_space.h -= child.clamped_bounds.h;
				}
			},
		}
	}
	return 0;
}

pub fn updatePositionZList(self: *widget.ZWidget, dirty: bool, w: f32, h: f32) callconv(.c) c_int {
	const children = self.getChildren() catch return @intFromEnum(root.errors.ZErrorC.updatePositionFailed);

	const margin = self.margin.asPixel(.{.w = w, .h = h}, self.window.?);
	self.clamped_bounds.x += margin.left;
	self.clamped_bounds.y += margin.top;

	var new_space = self.clamped_bounds;
	var child_layout_dirty = true;

	if (!dirty) {
		child_layout_dirty = false;
		for (children) |child| {
			if (child.flags.layout_dirty) {
				child_layout_dirty = true;
				break;
			}
		}
	}

	if (!child_layout_dirty) {
		for (children) |child| {
			child.updatePosition(false, self.clamped_bounds.w, self.clamped_bounds.h) catch return @intFromEnum(root.errors.ZErrorC.updatePositionFailed);
		}
		return 0;
	}

	if (self.getData(ZList)) |data| {
		switch (data.direction) {
			.horizontal => {
				for (children) |child| {
					const width = child.clamped_bounds.w;
					child.clamped_bounds.x += new_space.x;
					child.clamped_bounds.y += new_space.y;
					child.updatePosition(true, self.clamped_bounds.w, self.clamped_bounds.h) catch return @intFromEnum(root.errors.ZErrorC.updatePositionFailed);

					new_space.x += width + data.spacing;
				}
			},
			.vertical => {
				for (children) |child| {
					const height = child.clamped_bounds.h;
					child.clamped_bounds.x += new_space.x;
					child.clamped_bounds.y += new_space.y;
					child.updatePosition(true, self.clamped_bounds.w, self.clamped_bounds.h) catch return @intFromEnum(root.errors.ZErrorC.updatePositionFailed);

					new_space.y += height + data.spacing;
				}
			},
		}
	}
	return 0;
}

fn initZList(self: *widget.ZWidget) callconv(.c) c_int {
	const data = root.allocator.create(ZList) catch return @intFromEnum(root.errors.ZErrorC.OutOfMemory);
	data.* = .{
		.children = std.ArrayList(*widget.ZWidget).initCapacity(root.allocator, 0) catch return @intFromEnum(root.errors.ZErrorC.OutOfMemory),
	};
	self.type_name = @typeName(ZList);
	self.data = data;
	return 0;
}

fn deinitZList(self: *widget.ZWidget) callconv(.c) void {
	if (self.getData(ZList)) |data| {
		for (data.children.items) |c| {
			c.exitTreeExceptParent();
			c.deinit();
		}
		data.children.deinit(root.allocator);
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn getChildrenZList(self: *widget.ZWidget, return_len: *usize) callconv(.c) [*]*widget.ZWidget {
	if (self.getData(ZList)) |data| {
		return_len.* = data.children.items.len;
		return data.children.items.ptr;
	}
	return_len.* = 0;
	return &[0]*widget.ZWidget{};
}

fn removeChildZList(self: *widget.ZWidget, child: *widget.ZWidget) callconv(.c) c_int {
	if (self.getData(ZList)) |data| {
		for (data.children.items, 0..) |item, i| {
			if (item == child) {
				_ = data.children.orderedRemove(i);
				break;
			}
		}
	}
	return 0;
}

pub fn zList() *ZListBuilder {
	return ZListBuilder.init() catch |e| {
		std.debug.panic("{}", .{e});
	};
}

pub const ZListBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *widget.ZWidget,

	pub fn init() anyerror!*@This() {
		const self = try root.allocator.create(@This());

		self.widget = try widget.ZWidget.init(&ZListFI);

		return self;
	}

	pub fn build(self: *@This()) *widget.ZWidget {
		const final = self.widget;
		root.allocator.destroy(self);
		return final;
	}

	pub fn direction(self: *@This(), d: types.ZDirection) *@This() {
		if (self.widget.getData(ZList)) |data| {
			data.direction = d;
		}
		return self;
	}

	pub fn spacing(self: *@This(), f: f32) *@This() {
		if (self.widget.getData(ZList)) |data| {
			data.spacing = f;
		}
		return self;
	}

	pub fn children(self: *@This(), c: anytype) *@This() {
		if (self.widget.getData(ZList)) |data| {
			const ArgsType = @TypeOf(c);
			const args_type_info = @typeInfo(ArgsType);
			if (args_type_info != .@"struct") {
				@compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
			}

			const fields_info = args_type_info.@"struct".fields;
			inline for (fields_info) |f| {
				const child = @field(c, f.name);
				child.parent = self.widget;
				child.window = self.widget.window;
				data.children.append(root.allocator, child) catch |e| {
					std.log.err("list builder error: {}", .{e});
				};
			}
		}
		return self;
	}
};
