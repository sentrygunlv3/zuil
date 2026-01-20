const std = @import("std");
const root = @import("../root.zig");

const types = root.types;
const ZBounds = root.types.ZBounds;
const ZPosition = root.types.ZPosition;
const ZSize = root.types.ZSize;
const ZMargin = root.types.ZMargin;
const ZAlign = root.types.ZAlign;

/// base widget struct
/// 
/// when creating a widget setting `fi` is used to choose the type\
/// `mutable_fi` is for functions that can be changed after creation and are not directly linked to the type
/// 
/// `type_name` has to have the name of the struct stored in `data`
pub const ZWidget = struct {
	type_name: []const u8 = "ZWidget",
	mutable_fi: ZWidgetMutableFI = .{},
	fi: *const ZWidgetFI,
	flags: packed struct {
		layout_dirty: bool = true,
		keep_size_ratio: bool = false,
		_: u6 = 0,
	} = .{},
	data: ?*anyopaque = null,
	// tree
	parent: ?*ZWidget = null,
	window: ?*root.ZWidgetTree = null,
	// calculated
	clamped_bounds: ZBounds = .zero(),
	size_ratio: f32 = 0,
	// layout
	size: ZSize = .zero(),
	size_min: ZSize = .zero(),
	size_max: ZSize = .fill(),
	margin: ZMargin = .zero(),

	pub fn init(fi: *const ZWidgetFI) anyerror!*@This() {
		const self = try root.allocator.create(@This());
		self.* = @This(){
			.fi = fi,
		};
		if (self.fi.init) |func| {
			try func(self);
		}
		return self;
	}

	/// call destroy when removing widget from window/tree
	pub fn deinit(self: *@This()) void {
		if (self.fi.deinit) |func| {
			func(self);
		}
		root.allocator.destroy(self);
	}

	pub fn enterTree(self: *@This()) void {
		if (self.fi.enterTree) |func| {
			func(self);
		}
	}

	/// removes references from everything in the tree except the parent widget
	pub fn exitTreeExceptParent(self: *@This()) void {
		if (self.fi.exitTree) |func| {
			func(self);
		}
		if (self.window) |window| {
			if (window.focused_widget == self) {
				window.focused_widget = null;
			}
			self.setWindow(null);
		}
	}

	pub fn exitTree(self: *@This()) void {
		self.exitTreeExceptParent();
		if (self.parent != null) {
			self.parent.?.removeChild(self) catch |e| {
				std.debug.print("exit tree: {}\n", .{e});
			};
			self.parent = null;
		}
	}

	pub fn destroy(self: *@This()) void {
		self.exitTree();
		self.deinit();
	}

	pub fn markDirty(self: *@This()) void {
		self.flags.layout_dirty = true;
		if (self.window) |window| {
			window.markDirty();
			window.markDirtyRender(self.clamped_bounds);
		}
	}

	pub fn markDirtyRender(self: *@This()) void {
		if (self.window) |window| {
			window.markDirtyRender(self.clamped_bounds);
		}
	}

	// ---

	pub fn setSize(self: *@This(), new: ZSize) void {
		self.size = new;
		self.markDirty();
	}

	pub fn setKeepRatio(self: *@This(), new: bool) void {
		self.flags.keep_size_ratio = new;
		self.markDirty();
	}

	pub fn getData(self: *@This(), T: type) ?*T {
		if (self.data) |d| {
			if (std.mem.eql(u8, self.type_name, @typeName(T))) {
				return @ptrCast(@alignCast(d));
			}
		}
		return null;
	}

	// ---

	pub fn setWindow(self: *@This(), window: ?*root.ZWidgetTree) void {
		self.window = window;
		if (window != null) {
			self.enterTree();
		}
		const children = self.getChildren() catch {
			return;
		};
		for (children) |child| {
			child.setWindow(window);
		}
	}

	pub fn render(self: *@This(), window: *root.ZWidgetTree, commands: *root.renderer.context.RenderCommandList, area: ?types.ZBounds) anyerror!void {
		if (@import("build_options").debug) {
			std.debug.print("\n{*} - {s}\n", .{self, self.type_name});
			std.debug.print("bounds: {}\n", .{self.clamped_bounds});
		}
		if (self.fi.render) |func| {
			try func(self, window, commands, area);
		}
	}

	pub fn updatePreferredSize(self: *@This(), dirty: bool, x: f32, y: f32) anyerror!void {
		if (self.fi.updatePreferredSize) |func| {
			try func(self, dirty, x, y);
		}
	}

	pub fn updateActualSize(self: *@This(), dirty: bool, x: f32, y: f32) anyerror!void {
		if (self.fi.updateActualSize) |func| {
			try func(self, dirty, x, y);
		}
	}

	pub fn updatePosition(self: *@This(), dirty: bool, w: f32, h: f32) anyerror!void {
		if (self.fi.updatePosition) |func| {
			try func(self, dirty, w, h);
		}
		self.flags.layout_dirty = false;
		self.window.?.markDirtyRender(self.clamped_bounds);
	}

	pub fn isOverPoint(self: *@This(), x: f32, y: f32, parent_outside: bool) ?*@This() {
		if (self.fi.isOverPoint) |func| {
			return func(self, x, y, parent_outside);
		}
		return null;
	}

	pub fn event(self: *@This(), e: root.input.ZEvent) anyerror!void {
		if (self.mutable_fi.event) |func| {
			try func(self, e);
		}
	}

	pub fn getChildren(self: *@This()) anyerror![]*ZWidget {
		if (self.fi.getChildren) |func| {
			return func(self);
		}
		return root.ZError.MissingWidgetFunction;
	}

	/// this only removes the child from the parent
	/// 
	/// to remove the child from the whole tree call `exitTree` on the child
	/// 
	/// to destroy the child call `destroy` on the child
	pub fn removeChild(self: *@This(), child: *@This()) anyerror!void {
		if (self.fi.removeChild) |func| {
			try func(self, child);
		}
		return root.ZError.MissingWidgetFunction;
	}
};

/// widget function interface for widget classes
pub const ZWidgetFI = struct {
	init: ?*const fn (self: *ZWidget) anyerror!void = null,
	deinit: ?*const fn (self: *ZWidget) void = null,

	enterTree: ?*const fn (self: *ZWidget) void = null,
	exitTree: ?*const fn (self: *ZWidget) void = null,

	/// bottom to top
	updatePreferredSize: ?*const fn (self: *ZWidget, dirty: bool, x: f32, y: f32) anyerror!void = updatePreferredSize,
	/// top to bottom
	updateActualSize: ?*const fn (self: *ZWidget, dirty: bool, x: f32, y: f32) anyerror!void = updateActualSize,
	/// top to bottom
	updatePosition: ?*const fn (self: *ZWidget, dirty: bool, w: f32, h: f32) anyerror!void = updatePosition,

	render: ?*const fn (self: *ZWidget, window: *root.ZWidgetTree, commands: *root.renderer.context.RenderCommandList, area: ?types.ZBounds) anyerror!void = renderWidget,

	isOverPoint: ?*const fn (self: *ZWidget, x: f32, y: f32, parent_outside: bool) ?*ZWidget = isOverPointWidget,

	getChildren: ?*const fn (self: *ZWidget) []*ZWidget = null,
	removeChild: ?*const fn (self: *ZWidget, child: *ZWidget) anyerror!void = null,
};

/// widget function interface for per widget functions
pub const ZWidgetMutableFI = struct {
	event: ?*const fn (self: *ZWidget, event: root.input.ZEvent) anyerror!void = null,
};

pub fn renderWidget(self: *ZWidget, window: *root.ZWidgetTree, commands: *root.renderer.context.RenderCommandList, area: ?types.ZBounds) anyerror!void {
	const children = self.getChildren() catch {
		return;
	};
	for (children) |child| {
		_ = try child.render(window, commands, area);
	}
}

pub fn isOverPointWidget(self: *ZWidget, x: f32, y: f32, parent_outside: bool) ?*ZWidget {
	var ref: ?*ZWidget = null;
	var outside = true;

	if (!parent_outside) {
		if (
			self.clamped_bounds.x < x and
			self.clamped_bounds.x + self.clamped_bounds.w > x and
			self.clamped_bounds.y < y and
			self.clamped_bounds.y + self.clamped_bounds.h > y
		) {
			ref = self;
			outside = false;
		}
	}

	const children = self.getChildren() catch |e| {
		std.debug.print("{}\n", .{e});
		return null;
	};

	for (children) |child| {
		if (child.isOverPoint(x, y, outside)) |new| {
			ref = new;
		}
	}
	return ref;
}

pub fn updatePreferredSize(self: *ZWidget, dirty: bool, w: f32, h: f32) anyerror!void {
	if (dirty) {
		const size_w = if (self.size.w == .percentage) 0 else self.size.w.asPixel(false, .{.w = w, .h = h}, self.window.?);
		const size_h = if (self.size.h == .percentage) 0 else self.size.h.asPixel(true, .{.w = w, .h = h}, self.window.?);

		self.clamped_bounds = .{
			.w = size_w,
			.h = size_h,
		};

		self.size_ratio = size_w / size_h;
	} else {
		const children = self.getChildren() catch {
			return;
		};
		for (children) |child| {
			try child.updatePreferredSize(
				dirty or child.flags.layout_dirty,
				w,
				h
			);
		}
		return;
	}

	const children = self.getChildren() catch {
		return;
	};

	const size_max_w = if (self.size_max.w == .percentage) 0 else self.size_max.w.asPixel(false, .{.w = w, .h = h}, self.window.?);
	const size_max_h = if (self.size_max.h == .percentage) 0 else self.size_max.h.asPixel(true, .{.w = w, .h = h}, self.window.?);

	for (children) |child| {
		try child.updatePreferredSize(
			dirty or child.flags.layout_dirty,
			w,
			h
		);
		if (self.clamped_bounds.w < child.clamped_bounds.w) {
			if (child.clamped_bounds.w > size_max_w) {
				self.clamped_bounds.w = size_max_w;
			} else {
				self.clamped_bounds.w = child.clamped_bounds.w;
			}
		}

		if (self.clamped_bounds.h < child.clamped_bounds.h) {
			if (child.clamped_bounds.h > size_max_h) {
				self.clamped_bounds.h = size_max_h;
			} else {
				self.clamped_bounds.h = child.clamped_bounds.h;
			}
		}
	}
}

pub fn updateActualSize(self: *ZWidget, dirty: bool, w: f32, h: f32) anyerror!void {
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
		return;
	};

	for (children) |child| {
		try child.updateActualSize(
			dirty or child.flags.layout_dirty,
			self.clamped_bounds.w,
			self.clamped_bounds.h
		);
	}
}

/// dirty forces all widgets from this point on to recalculate their layouts
pub fn updatePosition(self: *ZWidget, dirty: bool, w: f32, h: f32) anyerror!void {
	const margin = self.margin.asPixel(.{.w = w, .h = h}, self.window.?);
	self.clamped_bounds.x += margin.left;
	self.clamped_bounds.y += margin.top;

	const children = self.getChildren() catch {
		return;
	};

	for (children) |child| {
		child.clamped_bounds.x = self.clamped_bounds.x;
		child.clamped_bounds.y = self.clamped_bounds.y;
		try child.updatePosition(dirty or child.flags.layout_dirty, self.clamped_bounds.w, self.clamped_bounds.h);
	}
}
