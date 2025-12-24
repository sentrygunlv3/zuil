const std = @import("std");
const root = @import("../root.zig");

const widget = root.uwidget;
const UColor = root.color.UColor;
const shader = root.shader;
const types = root.types;

pub fn uList() *UListBuilder {
	return UListBuilder.init() catch |e| {
		std.log.err("{}", .{e});
		std.process.exit(1);
		unreachable;
	};
}

pub const UListFI = widget.UWidgetFI{
	.init = initUList,
	.deinit = deinitUList,
	.getChildren = getChildrenUList,
	.update = updateUList,
};

fn updateUList(self: *widget.UWidget, window: *root.UWindow, space: types.UBounds, alignment: types.UAlign) anyerror!void {
	const new_space = widget.updateWidgetSelf(self, space, alignment);

	const children = try self.getChildren();
	const children_len: f32 = @floatFromInt(children.items.len);
	var child_space = new_space;

	if (getData(self)) |data| {
		switch (data.direction) {
			.horizontal => {
				child_space.w = new_space.w / children_len;

				for (children.items) |child| {
					_ = try child.update(window, child_space, self.content_alignment);
					child_space.x += child_space.w;
				}
			},
			.vertical => {
				child_space.h = new_space.h / children_len;

				for (children.items) |child| {
					_ = try child.update(window, child_space, self.content_alignment);
					child_space.y += child_space.h;
				}
			},
		}
	}
}

fn initUList(self: *widget.UWidget) anyerror!void {
	self.type_name = "UList";
	const data = try root.allocator.create(UListData);
	data.* = UListData{
		.direction = types.UDirection.default(),
		.children = try std.ArrayList(*widget.UWidget).initCapacity(root.allocator, 0),
	};
	self.data = data;
}

fn deinitUList(self: *widget.UWidget) void {
	if (getData(self)) |data| {
		for (data.children.items) |c| {
			c.deinit();
		}
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn getChildrenUList(self: *widget.UWidget) anyerror!std.ArrayList(*widget.UWidget) {
	if (getData(self)) |data| {
		return data.children;
	}
	return root.UError.NoWidgetData;
}

pub const UListBuilder = struct {
	widget: *widget.UWidget,

	pub fn init() anyerror!*@This() {
		const self = try root.allocator.create(@This());

		self.widget = try widget.UWidget.init(UListFI);

		return self;
	}

	pub fn build(self: *@This()) *widget.UWidget {
		const final = self.widget;
		root.allocator.destroy(self);
		return final;
	}

	pub fn bounds(self: *@This(), w: f32, h: f32) *@This() {
		self.widget.bounds = .{.w = w, .h = h};
		return self;
	}

	pub fn margin(self: *@This(), top: f32, bottom: f32, left: f32, right: f32) *@This() {
		self.widget.margin = .{
			.top = top,
			.bottom = bottom,
			.left = left,
			.right = right
		};
		return self;
	}

	pub fn content_align(self: *@This(), a: types.UAlign) *@This() {
		self.widget.content_alignment = a;
		return self;
	}

	pub fn layout(self: *@This(), l: types.ULayout) *@This() {
		self.widget.layout = l;
		return self;
	}

	pub fn direction(self: *@This(), d: types.UDirection) *@This() {
		if (getData(self.widget)) |data| {
			data.*.direction = d;
		}
		return self;
	}

	pub fn children(self: *@This(), c: anytype) *@This() {
		if (getData(self.widget)) |data| {
			const ArgsType = @TypeOf(c);
			const args_type_info = @typeInfo(ArgsType);
			if (args_type_info != .@"struct") {
				@compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
			}

			const fields_info = args_type_info.@"struct".fields;
			inline for (fields_info) |f| {
				const child = @field(c, f.name);
				child.parent = self.widget;
				data.*.children.append(root.allocator, child) catch |e| {
					std.log.err("list builder error: {}", .{e});
				};
			}
		}
		return self;
	}
};

pub const UListData = struct {
	direction: types.UDirection,
	children: std.ArrayList(*widget.UWidget),
};

fn getData(self: *widget.UWidget) ?*UListData {
	if (self.data) |d| {
		return @ptrCast(@alignCast(d));
	}
	return null;
}
