const std = @import("std");
const root = @import("../root.zig");
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const widget = root.zwidget;
const ZColor = root.color.ZColor;
const shader = root.shader;
const types = root.types;

pub fn zList() *ZListBuilder {
	return ZListBuilder.init() catch |e| {
		std.debug.panic("{}", .{e});
	};
}

pub const ZListFI = widget.ZWidgetFI{
	.init = initZList,
	.deinit = deinitZList,
	.getChildren = getChildrenZList,
	.update = updateZList,
};

fn updateZList(self: *widget.ZWidget, dirty: bool) anyerror!void {
	const children = try self.getChildren();
	const children_len: f32 = @floatFromInt(children.len);

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
			_ = try child.update(false);
		}
		return;
	}

	if (self.getData(ZList)) |data| {
		switch (data.direction) {
			.horizontal => {
				new_space.w = (new_space.w - data.spacing * (children_len - 1)) / children_len;

				for (children) |child| {
					_ = try child.updateSize(new_space.w, new_space.h, self.content_alignment);
					
					child.clamped_bounds.x += new_space.x;
					child.clamped_bounds.y += new_space.y;
					_ = try child.update(true);

					new_space.x += new_space.w + data.spacing;
				}
			},
			.vertical => {
				new_space.h = (new_space.h - data.spacing * (children_len - 1)) / children_len;

				for (children) |child| {
					_ = try child.updateSize(new_space.w, new_space.h, self.content_alignment);
					
					child.clamped_bounds.x += new_space.x;
					child.clamped_bounds.y += new_space.y;
					_ = try child.update(true);

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

pub const ZList = struct {
	direction: types.ZDirection = types.ZDirection.default(),
	spacing: f32 = 0,
	children: std.ArrayList(*widget.ZWidget) = undefined,
};
