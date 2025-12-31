const std = @import("std");
const root = @import("root.zig");

const types = root.types;
const ZBounds = root.types.ZBounds;
const ZMargin = root.types.ZMargin;
const ZAlign = root.types.ZAlign;
const ZLayout = root.types.ZLayout;

pub const ZWidget = struct {
	type_name: []const u8 = "ZWidget",
	mutable_fi: ZWidgetMutableFI = .{},
	fi: *const ZWidgetFI,
	// ---
	parent: ?*ZWidget = null,
	window: ?*root.ZWindow = null,
	data: ?*anyopaque = null,
	// ---
	bounds: ZBounds = ZBounds.zero(),
	clamped_bounds: ZBounds = ZBounds.zero(),
	// ---
	margin: ZMargin = ZMargin.zero(),
	content_alignment: ZAlign = ZAlign.default(),
	layout: ZLayout = ZLayout.default(),

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
		}
	}

	pub fn destroy(self: *@This()) void {
		self.exitTree();
		self.deinit();
	}

	pub fn getData(self: *@This(), T: type) ?*T {
		if (self.data) |d| {
			if (std.mem.eql(u8, self.type_name, @typeName(T))) {
				return @ptrCast(@alignCast(d));
			}
		}
		return null;
	}

	pub fn render(self: *@This(), window: *root.ZWindow) anyerror!void {
		std.debug.print("\n{*}\n", .{self});
		std.debug.print("bounds: {}\n", .{self.clamped_bounds});
		if (self.fi.render) |func| {
			try func(self, window);
		}
	}

	pub fn update(self: *@This(), space: ZBounds, alignment: ZAlign) anyerror!void {
		if (self.fi.update) |func| {
			try func(self, space, alignment);
		}
	}

	pub fn isOverPoint(self: *@This(), x: f32, y: f32) ?*@This() {
		if (self.fi.isOverPoint) |func| {
			return func(self, x, y);
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

pub const ZWidgetFI = struct {
	init: ?*const fn (self: *ZWidget) anyerror!void = null,
	deinit: ?*const fn (self: *ZWidget) void = null,
	render: ?*const fn (self: *ZWidget, window: *root.ZWindow) anyerror!void = renderWidget,
	update: ?*const fn (self: *ZWidget, space: ZBounds, alignment: ZAlign) anyerror!void = updateWidget,
	isOverPoint: ?*const fn (self: *ZWidget, x: f32, y: f32) ?*ZWidget = isOverPointWidget,
	getChildren: ?*const fn (self: *ZWidget) []*ZWidget = null,
};

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

pub fn isOverPointWidget(self: *ZWidget, x: f32, y: f32) ?*ZWidget {
	var ref: ?*ZWidget = null;

	if (
		self.clamped_bounds.x < x and
		self.clamped_bounds.x + self.clamped_bounds.w > x and
		self.clamped_bounds.y < y and
		self.clamped_bounds.y + self.clamped_bounds.h > y
	) {
		ref = self;
	}

	const children = self.getChildren() catch |e| {
		std.debug.print("{}\n", .{e});
		return null;
	};

	for (children) |child| {
		if (child.isOverPoint(x, y)) |new| {
			ref = new;
		}
	}
	return ref;
}

pub fn updateWidget(self: *ZWidget, space: ZBounds, alignment: ZAlign) anyerror!void {
	const new_space = updateWidgetSelf(self, space, alignment);

	const children = self.getChildren() catch {
		return;
	};
	for (children) |child| {
		_ = try child.update(new_space, alignment);
	}
}

pub fn updateWidgetSelf(self: *ZWidget, space: ZBounds, alignment: ZAlign) ZBounds {
	switch (self.layout) {
		.absolute => {
			self.clamped_bounds = self.bounds;
		},
		.fill => {
			self.clamped_bounds = space;
		},
		.normal => {
			self.clamped_bounds = self.bounds;
			if (self.bounds.h > space.h) {
				self.clamped_bounds.h = space.h;
			}
			if (self.bounds.w > space.w) {
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
			self.clamped_bounds.x = (space.x + offsetx) + self.bounds.x;
			self.clamped_bounds.y = (space.y + offsety) - self.bounds.y;
		},
		else => {
			self.clamped_bounds.x = space.x + offsetx;
			self.clamped_bounds.y = space.y + offsety;
		}
	}

	self.clamped_bounds.w -= (self.margin.left + self.margin.right);
	self.clamped_bounds.h -= (self.margin.top + self.margin.bottom);
	self.clamped_bounds.x += self.margin.left;
	self.clamped_bounds.y += self.margin.top;

	return self.clamped_bounds;
}
