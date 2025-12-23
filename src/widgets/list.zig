const std = @import("std");
const widget = @import("../widget.zig");
const root = @import("../root.zig");
const UColor = @import("../color.zig").UColor;
pub const shader = @import("../shader_registry.zig");

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
	.render = widget.renderWidget,
	.getChildren = getChildrenUList,
};

fn initUList(self: *widget.UWidget) anyerror!void {
	self.type_name = "UList";
	const data = try root.allocator.create(UListData);
	data.* = UListData{
		.direction = widget.UDirection.default(),
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

const UListBuilder = struct {
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

	pub fn content_align(self: *@This(), a: widget.UAlign) *@This() {
		self.widget.content_alignment = a;
		return self;
	}

	pub fn layout(self: *@This(), l: widget.ULayout) *@This() {
		self.widget.layout = l;
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
	direction: widget.UDirection,
	children: std.ArrayList(*widget.UWidget),
};

fn getData(self: *widget.UWidget) ?*UListData {
	if (self.data) |d| {
		return @ptrCast(@alignCast(d));
	}
	return null;
}
