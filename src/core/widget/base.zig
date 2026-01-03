const std = @import("std");
const root = @import("../root.zig");

const types = root.types;
const ZBounds = root.types.ZBounds;
const ZPosition = root.types.ZPosition;
const ZSize = root.types.ZSize;
const ZMargin = root.types.ZMargin;
const ZAlign = root.types.ZAlign;
const ZLayout = root.types.ZLayout;

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
		_: u7 = 0,
	} = .{},
	data: ?*anyopaque = null,
	// tree
	parent: ?*ZWidget = null,
	window: ?*root.ZWindow = null,
	// calculated
	clamped_bounds: ZBounds = .zero(),
	// layout
	position: ZPosition = .zero(),
	size: ZSize = .zero(),
	margin: ZMargin = .zero(),
	content_alignment: ZAlign = .default(),
	layout: ZLayout = .default(),

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

	pub fn exitTree(self: *@This()) void {
		if (self.window) |window| {
			if (window.focused_widget == self) {
				window.focused_widget = null;
			}
			self.window = null;
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
		}
	}

	pub fn markDirtyRender(self: *@This()) void {
		if (self.window) |window| {
			window.flags.render_dirty = true;
		}
	}

	// ---

	pub fn setPosition(self: *@This(), new: ZPosition) void {
		self.position = new;
		self.markDirty();
	}

	pub fn setSize(self: *@This(), new: ZSize) void {
		self.size = new;
		self.markDirty();
	}

	pub fn setMargin(self: *@This(), new: ZMargin) void {
		self.margin = new;
		self.markDirty();
	}

	pub fn setContentAlignment(self: *@This(), new: ZAlign) void {
		self.content_alignment = new;
		self.markDirty();
	}

	pub fn setLayout(self: *@This(), new: ZLayout) void {
		self.layout = new;
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

	pub fn setWindow(self: *@This(), window: *root.ZWindow) void {
		self.window = window;
		const children = self.getChildren() catch {
			return;
		};
		for (children) |child| {
			child.setWindow(window);
		}
	}

	pub fn render(self: *@This(), window: *root.ZWindow) anyerror!void {
		std.debug.print("\n{*} - {s}\n", .{self, self.type_name});
		std.debug.print("bounds: {}\n", .{self.clamped_bounds});
		if (self.fi.render) |func| {
			try func(self, window);
		}
	}

	pub fn updateSize(self: *@This(), x: f32, y: f32, alignment: ZAlign) anyerror!void {
		std.debug.print("\n{*}\n", .{self});
		if (self.fi.updateSize) |func| {
			try func(self, x, y, alignment);
		}
	}

	pub fn update(self: *@This(), dirty: bool) anyerror!void {
		if (self.fi.update) |func| {
			try func(self, dirty);
		}
		self.flags.layout_dirty = false;
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
};

/// widget function interface for widget classes
pub const ZWidgetFI = struct {
	init: ?*const fn (self: *ZWidget) anyerror!void = null,
	deinit: ?*const fn (self: *ZWidget) void = null,

	updateSize: ?*const fn (self: *ZWidget, x: f32, y: f32, alignment: ZAlign) anyerror!void = updateSizeWidget,
	update: ?*const fn (self: *ZWidget, dirty: bool) anyerror!void = updateWidget,

	render: ?*const fn (self: *ZWidget, window: *root.ZWindow) anyerror!void = renderWidget,

	isOverPoint: ?*const fn (self: *ZWidget, x: f32, y: f32, parent_outside: bool) ?*ZWidget = isOverPointWidget,
	getChildren: ?*const fn (self: *ZWidget) []*ZWidget = null,
};

/// widget function interface for per widget functions
pub const ZWidgetMutableFI = struct {
	event: ?*const fn (self: *ZWidget, event: root.input.ZEvent) anyerror!void = null,
};

pub fn renderWidget(self: *ZWidget, window: *root.ZWindow) anyerror!void {
	const children = self.getChildren() catch {
		return;
	};
	for (children) |child| {
		_ = try child.render(window);
	}
}

pub fn isOverPointWidget(self: *ZWidget, x: f32, y: f32, parent_outside: bool) ?*ZWidget {
	var ref: ?*ZWidget = null;
	var outside = true;

	if (!parent_outside or self.layout == ZLayout.absolute) {
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

/// dirty forces all widgets from this point on to recalculate their layouts
pub fn updateWidget(self: *ZWidget, dirty: bool) anyerror!void {
	const children = self.getChildren() catch {
		return;
	};

	for (children) |child| {
		if (dirty or child.flags.layout_dirty) {
			_ = try child.updateSize(self.clamped_bounds.w, self.clamped_bounds.h, self.content_alignment);
			child.clamped_bounds.x += self.clamped_bounds.x;
			child.clamped_bounds.y += self.clamped_bounds.y;
			_ = try child.update(true);
		} else {
			_ = try child.update(false);
		}
	}
}

pub fn updateSizeWidget(self: *ZWidget, w: f32, h: f32, alignment: ZAlign) anyerror!void {
	const space: ZBounds = .{
		.w = w,
		.h = h,
	};

	if (self.window == null) {
		std.debug.print("updateSizeWidget: no window\n", .{});
		return;
	}

	const size_bounds = self.size.asBounds(space, self.window.?);
	const pos_bounds = self.position.asBounds(space, self.window.?);
	const bounds: ZBounds = .{
		.w = size_bounds.w,
		.h = size_bounds.h,
		.x = pos_bounds.x,
		.y = pos_bounds.y,
	};
	switch (self.layout) {
		.absolute => {
			self.clamped_bounds = bounds;
		},
		.fill => {
			self.clamped_bounds = space;
		},
		.normal => {
			self.clamped_bounds = bounds;
			if (bounds.h > space.h) {
				self.clamped_bounds.h = space.h;
			}
			if (bounds.w > space.w) {
				self.clamped_bounds.w = space.w;
			}
		},
	}

	var offsetx: f32 = 0;
	var offsety: f32 = 0;

	switch (alignment) {
		.topLeft => {},
		.top => {
			offsetx = (space.w - self.clamped_bounds.w) * 0.5;
		},
		.topRight => {
			offsetx = space.w - self.clamped_bounds.w;
		},
		.left => {
			offsety = (space.h - self.clamped_bounds.h) * 0.5;
		},
		.center => {
			offsetx = (space.w - self.clamped_bounds.w) * 0.5;
			offsety = (space.h - self.clamped_bounds.h) * 0.5;
		},
		.right => {
			offsetx = space.w - self.clamped_bounds.w;
			offsety = (space.h - self.clamped_bounds.h) * 0.5;
		},
		.bottomLeft => {
			offsety = space.h - self.clamped_bounds.h;
		},
		.bottom => {
			offsetx = (space.w - self.clamped_bounds.w) * 0.5;
			offsety = space.h - self.clamped_bounds.h;
		},
		.bottomRight => {
			offsetx = space.w - self.clamped_bounds.w;
			offsety = space.h - self.clamped_bounds.h;
		},
	}

	switch (self.layout) {
		.absolute => {
			self.clamped_bounds.x = (space.x + offsetx) + bounds.x;
			self.clamped_bounds.y = (space.y + offsety) - bounds.y;
		},
		else => {
			self.clamped_bounds.x = space.x + offsetx;
			self.clamped_bounds.y = space.y + offsety;
		}
	}

	const margin = self.margin.asPixel(space, self.window.?);
	self.clamped_bounds.w -= (margin.left + margin.right);
	self.clamped_bounds.h -= (margin.top + margin.bottom);
	self.clamped_bounds.x += margin.left;
	self.clamped_bounds.y += margin.top;
}
