const std = @import("std");
const zuil = @import("zuilcore");
const BuilderMixin = zuil.widget.BuilderMixin;

const ZWidget = zuil.widget.ZWidget;
const ZColor = zuil.color.ZColor;
const types = zuil.types;

pub const ZList = struct {
	direction: types.ZDirection = types.ZDirection.default,
	spacing: f32 = 0,
	children: std.ArrayList(*ZWidget) = undefined,

	super: ZWidget = .{.fi = &vtable},

	pub const vtable = ZWidget.VTable.generate(@This());

	pub fn init(context: *zuil.context.ZContext) !*@This() {
		const self = try context.allocator.create(@This());
		self.* = .{
			.children = try std.ArrayList(*ZWidget).initCapacity(context.allocator, 0),
		};
		return self;
	}

	pub fn deinit(widget: *ZWidget, context: *zuil.context.ZContext) void {
		const self: *@This() = widget.as(@This());

		for (self.children.items) |c| {
			c.exitTreeExceptParent(context);
			c.deinit(context);
		}
		self.children.deinit(context.allocator);
		context.allocator.destroy(self);
	}

	pub fn updateActualSize(widget: *ZWidget, dirty: bool, w: f32, h: f32) !void {
		const self: *@This() = widget.as(@This());

		if (dirty) {
			const size_max_w = widget.size_max.w.asPixel(false, .{.w = w, .h = h}, widget.window.?);
			const size_max_h = widget.size_max.h.asPixel(true, .{.w = w, .h = h}, widget.window.?);

			if (widget.size.w == .percentage) {
				widget.clamped_bounds.w = widget.size.w.asPixel(false, .{.w = w, .h = h}, widget.window.?);
			}
			if (widget.size.h == .percentage) {
				widget.clamped_bounds.h = widget.size.h.asPixel(true, .{.w = w, .h = h}, widget.window.?);
			}

			if (widget.clamped_bounds.w > size_max_w) {
				widget.clamped_bounds.w = size_max_w;
			}
			if (widget.clamped_bounds.h > size_max_h) {
				widget.clamped_bounds.h = size_max_h;
			}
		}

		var new_space = widget.clamped_bounds;
		var child_layout_dirty = true;

		if (!dirty) {
			child_layout_dirty = false;
			for (self.children.items) |child| {
				if (child.flags.layout_dirty) {
					child_layout_dirty = true;
					break;
				}
			}
		}

		if (!child_layout_dirty) {
			for (self.children.items) |child| {
				try child.updateActualSize(
					false,
					widget.clamped_bounds.w,
					widget.clamped_bounds.h
				);
			}
		}

		switch (self.direction) {
			.horizontal => {
				for (self.children.items) |child| {
					try child.updateActualSize(
						dirty or child.flags.layout_dirty,
						if (child.clamped_bounds.w > new_space.w or child.size.w == .percentage) new_space.w else child.clamped_bounds.w,
						new_space.h
					);
					new_space.w -= child.clamped_bounds.w + self.spacing;
				}
			},
			.vertical => {
				for (self.children.items) |child| {
					try child.updateActualSize(
						dirty or child.flags.layout_dirty,
						new_space.w,
						if (child.clamped_bounds.h > new_space.h or child.size.h == .percentage) new_space.h else child.clamped_bounds.h
					);
					new_space.h -= child.clamped_bounds.h + self.spacing;
				}
			},
		}
	}

	pub fn updatePosition(widget: *ZWidget, dirty: bool, w: f32, h: f32) !void {
		const self: *@This() = widget.as(@This());

		const margin = widget.margin.asPixel(.{.w = w, .h = h}, widget.window.?);
		widget.clamped_bounds.x += margin.left;
		widget.clamped_bounds.y += margin.top;

		var new_space = widget.clamped_bounds;
		var child_layout_dirty = true;

		if (!dirty) {
			child_layout_dirty = false;
			for (self.children.items) |child| {
				if (child.flags.layout_dirty) {
					child_layout_dirty = true;
					break;
				}
			}
		}

		if (!child_layout_dirty) {
			for (self.children.items) |child| {
				try child.updatePosition(false, widget.clamped_bounds.w, widget.clamped_bounds.h);
			}
			return;
		}

		switch (self.direction) {
			.horizontal => {
				for (self.children.items) |child| {
					const width = child.clamped_bounds.w;
					child.clamped_bounds.x += new_space.x;
					child.clamped_bounds.y += new_space.y;
					try child.updatePosition(true, widget.clamped_bounds.w, widget.clamped_bounds.h);

					new_space.x += width + self.spacing;
				}
			},
			.vertical => {
				for (self.children.items) |child| {
					const height = child.clamped_bounds.h;
					child.clamped_bounds.x += new_space.x;
					child.clamped_bounds.y += new_space.y;
					try child.updatePosition(true, widget.clamped_bounds.w, widget.clamped_bounds.h);

					new_space.y += height + self.spacing;
				}
			},
		}
	}

	pub fn getChildren(widget: *ZWidget) ![]*ZWidget {
		const self: *@This() = widget.as(@This());

		return self.children.items;
	}

	pub fn removeChild(widget: *ZWidget, child: *ZWidget) !void {
		const self: *@This() = widget.as(@This());

		for (self.children.items, 0..) |item, i| {
			if (item == child) {
				_ = self.children.orderedRemove(i);
				break;
			}
		}
	}
};

pub const ZListBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *ZList,
	context: *zuil.context.ZContext,

	pub fn init(context: *zuil.context.ZContext) anyerror!*@This() {
		const self = try context.allocator.create(@This());
		errdefer context.allocator.destroy(self);

		self.* = .{
			.widget = try ZList.init(context),
			.context = context,
		};

		return self;
	}

	pub fn build(self: *@This()) *ZWidget {
		const final = &self.widget.super;
		self.context.allocator.destroy(self);
		return final;
	}

	pub fn direction(self: *@This(), new: types.ZDirection) *@This() {
		self.widget.direction = new;
		return self;
	}

	pub fn spacing(self: *@This(), new: f32) *@This() {
		self.widget.spacing = new;
		return self;
	}

	pub fn children(self: *@This(), c: anytype) *@This() {
		const ArgsType = @TypeOf(c);
		const args_type_info = @typeInfo(ArgsType);
		if (args_type_info != .@"struct") {
			@compileError("expected tuple or struct argument, found " ++ @typeName(ArgsType));
		}

		const fields_info = args_type_info.@"struct".fields;
		inline for (fields_info) |f| {
			const child = @field(c, f.name);
			child.parent = &self.widget.super;
			child.window = self.widget.super.window;
			self.widget.children.append(self.context.allocator, child) catch |e| {
				std.log.err("list builder error: {}", .{e});
			};
		}

		return self;
	}
};
