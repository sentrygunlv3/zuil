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

fn updateUList(self: *widget.UWidget, space: types.UBounds, alignment: types.UAlign) anyerror!void {
	var new_space = widget.updateWidgetSelf(self, space, alignment);

	const children = try self.getChildren();
	const children_len: f32 = @floatFromInt(children.len);

	if (self.getData(UList)) |data| {
		switch (data.direction) {
			.horizontal => {
				new_space.w = (new_space.w - data.spacing * (children_len - 1)) / children_len;

				for (children) |child| {
					_ = try child.update(new_space, self.content_alignment);
					new_space.x += new_space.w + data.spacing;
				}
			},
			.vertical => {
				new_space.h = (new_space.h - data.spacing * (children_len - 1)) / children_len;

				for (children) |child| {
					_ = try child.update(new_space, self.content_alignment);
					new_space.y += new_space.h + data.spacing;
				}
			},
		}
	}
}

fn initUList(self: *widget.UWidget) anyerror!void {
	const data = try root.allocator.create(UList);
	data.* = .{
		.children = try std.ArrayList(*widget.UWidget).initCapacity(root.allocator, 0),
	};
	self.type_name = @typeName(UList);
	self.data = data;
}

fn deinitUList(self: *widget.UWidget) void {
	if (self.getData(UList)) |data| {
		for (data.children.items) |c| {
			c.destroy();
		}
		data.children.deinit(root.allocator);
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn getChildrenUList(self: *widget.UWidget) []*widget.UWidget {
	if (self.getData(UList)) |data| {
		return data.children.items;
	}
	return &[0]*widget.UWidget{};
}

pub const UListBuilder = struct {
	widget: *widget.UWidget,

	pub fn init() anyerror!*@This() {
		const self = try root.allocator.create(@This());

		self.widget = try widget.UWidget.init(&UListFI);

		return self;
	}

	pub fn build(self: *@This()) *widget.UWidget {
		const final = self.widget;
		root.allocator.destroy(self);
		return final;
	}

	pub fn bounds(self: *@This(), x: f32, y: f32, w: f32, h: f32) *@This() {
		self.widget.bounds = .{
			.x = x,
			.y = y,
			.w = w,
			.h = h
		};
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
		if (self.widget.getData(UList)) |data| {
			data.direction = d;
		}
		return self;
	}

	pub fn spacing(self: *@This(), f: f32) *@This() {
		if (self.widget.getData(UList)) |data| {
			data.spacing = f;
		}
		return self;
	}

	pub fn children(self: *@This(), c: anytype) *@This() {
		if (self.widget.getData(UList)) |data| {
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

pub const UList = struct {
	direction: types.UDirection = types.UDirection.default(),
	spacing: f32 = 0,
	children: std.ArrayList(*widget.UWidget) = undefined,
};
