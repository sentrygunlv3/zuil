const std = @import("std");
const root = @import("../root.zig").core;
const BuilderMixin = @import("../core/widget/builder.zig").BuilderMixin;

const ZWidget = root.widget.ZWidget;
const ZColor = root.color.ZColor;
const types = root.types;

pub const ZPosition = struct {
	x: f32 = 0,
	y: f32 = 0,
	absolute_size: bool = false,
	child: ?*ZWidget = null,

	super: ZWidget = .{.fi = &vtable},

	pub const vtable = ZWidget.VTable.generate(@This());

	pub fn init(context: *root.context.ZContext) !*@This() {
		const self = try context.allocator.create(@This());
		self.* = .{};
		return self;
	}

	pub fn deinit(widget: *ZWidget, context: *root.context.ZContext) void {
		const self: *@This() = widget.as(@This());

		if (self.child) |c| {
			c.exitTreeExceptParent(context);
			c.deinit(context);
		}
		context.allocator.destroy(self);
	}

	pub fn updateActualSize(widget: *ZWidget, dirty: bool, w: f32, h: f32) !void {
		const self: *@This() = widget.as(@This());

		const margin = widget.margin.asPixel(.{.w = w, .h = h}, widget.window.?);
		const width = w - (margin.left + margin.right);
		const height = h - (margin.top + margin.bottom);
		if (dirty) {
			const size_max_w = widget.size_max.w.asPixel(false, .{.w = width, .h = height}, widget.window.?);
			const size_max_h = widget.size_max.h.asPixel(true, .{.w = width, .h = height}, widget.window.?);

			if (widget.size.w == .percentage) {
				widget.clamped_bounds.w = widget.size.w.asPixel(false, .{.w = width, .h = height}, widget.window.?);
			}
			if (widget.size.h == .percentage) {
				widget.clamped_bounds.h = widget.size.h.asPixel(true, .{.w = width, .h = height}, widget.window.?);
			}

			if (widget.clamped_bounds.w > size_max_w) {
				widget.clamped_bounds.w = size_max_w;
			}
			if (widget.clamped_bounds.h > size_max_h) {
				widget.clamped_bounds.h = size_max_h;
			}

			if (widget.flags.keep_size_ratio) {
				if (width < height) {
					widget.clamped_bounds.h = widget.clamped_bounds.w / widget.size_ratio;
				} else {
					widget.clamped_bounds.w = widget.clamped_bounds.h * widget.size_ratio;
				}
			}
		}

		var space: root.types.ZBounds = .zero;
		if (self.absolute_size) {
			space = widget.window.?.getBounds();
		} else {
			space = widget.clamped_bounds;
		}

		if (self.child) |child| {
			try child.updateActualSize(
				dirty or child.flags.layout_dirty,
				space.w,
				space.h
			);
		}
	}

	pub fn getChildren(widget: *ZWidget) ![]*ZWidget {
		const self: *@This() = widget.as(@This());

		if (self.child) |child| {
			var s = [_]*ZWidget{child};
			return &s;
		}
		return &[_]*ZWidget{};
	}

	pub fn removeChild(widget: *ZWidget, child: *ZWidget) !void {
		const self: *@This() = widget.as(@This());

		if (self.child == child) {
			self.child = null;
		}
		return root.ZError.NoChildFound;
	}
};

pub const ZPositionBuilder = struct {
	/// common functions
	c: BuilderMixin(@This()) = .{},
	widget: *ZPosition,
	context: *root.context.ZContext,

	pub fn init(context: *root.context.ZContext) anyerror!*@This() {
		const self = try context.allocator.create(@This());
		errdefer context.allocator.destroy(self);

		self.* = .{
			.widget = try ZPosition.init(context),
			.context = context,
		};

		return self;
	}

	pub fn build(self: *@This()) *ZWidget {
		const final = &self.widget.super;
		self.context.allocator.destroy(self);
		return final;
	}

	pub fn position(self: *@This(), x: f32, y: f32) *@This() {
		self.widget.x = x;
		self.widget.y = y;
		return self;
	}

	pub fn absolute(self: *@This(), new: bool) *@This() {
		self.widget.absolute_size = new;
		return self;
	}

	pub fn child(self: *@This(), new: *ZWidget) *@This() {
		self.widget.child = new;
		self.widget.child.?.parent = &self.widget.super;
		self.widget.child.?.window = self.widget.super.window;

		return self;
	}
};
