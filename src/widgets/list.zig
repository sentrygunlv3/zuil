const std = @import("std");
const root = @import("../root.zig");

const widget = root.zwidget;
const ZColor = root.color.ZColor;
const shader = root.shader;
const types = root.types;

pub fn zList() *ZListBuilder {
	return ZListBuilder.init() catch |e| {
		std.log.err("{}", .{e});
		std.process.exit(1);
		unreachable;
	};
}

pub const ZListFI = widget.ZWidgetFI{
	.init = initZList,
	.deinit = deinitZList,
	.getChildren = getChildrenZList,
	.update = updateZList,
};

fn updateZList(self: *widget.ZWidget, space: types.ZBounds, alignment: types.ZAlign) anyerror!void {
	var new_space = widget.updateWidgetSelf(self, space, alignment);

	const children = try self.getChildren();
	const children_len: f32 = @floatFromInt(children.len);

	if (self.getData(ZList)) |data| {
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

fn initZList(self: *widget.ZWidget) anyerror!void {
	const data = try root.allocator.create(ZList);
	data.* = .{
		.children = try std.ArrayList(*widget.ZWidget).initCapacity(root.allocator, 0),
	};
	self.type_name = @typeName(ZList);
	self.data = data;
}

fn deinitZList(self: *widget.ZWidget) void {
	if (self.getData(ZList)) |data| {
		for (data.children.items) |c| {
			c.destroy();
		}
		data.children.deinit(root.allocator);
		root.allocator.destroy(data);
		self.data = null;
	}
}

fn getChildrenZList(self: *widget.ZWidget) []*widget.ZWidget {
	if (self.getData(ZList)) |data| {
		return data.children.items;
	}
	return &[0]*widget.ZWidget{};
}

pub const ZListBuilder = struct {
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

	pub fn content_align(self: *@This(), a: types.ZAlign) *@This() {
		self.widget.content_alignment = a;
		return self;
	}

	pub fn layout(self: *@This(), l: types.ZLayout) *@This() {
		self.widget.layout = l;
		return self;
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

pub const ZList = struct {
	direction: types.ZDirection = types.ZDirection.default(),
	spacing: f32 = 0,
	children: std.ArrayList(*widget.ZWidget) = undefined,
};
