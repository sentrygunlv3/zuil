const std = @import("std");
const root = @import("root.zig");

const types = root.types;
const UBounds = root.types.UBounds;
const UMargin = root.types.UMargin;
const UAlign = root.types.UAlign;
const ULayout = root.types.ULayout;

pub const UWidget = struct {
	type_name: []const u8 = "UWidget",
	fi: UWidgetFI,
	parent: ?*UWidget = null,
	window: ?*root.UWindow,
	data: ?*anyopaque = null,
	// ---
	bounds: UBounds = UBounds.zero(),
	clamped_bounds: UBounds = UBounds.zero(),
	// ---
	margin: UMargin = UMargin.zero(),
	content_alignment: UAlign = UAlign.default(),
	layout: ULayout = ULayout.default(),

	pub fn init(fi: UWidgetFI) anyerror!*@This() {
		const self = try root.allocator.create(@This());
		self.* = @This(){
			.fi = fi,
		};
		if (self.fi.init) |func| {
			try func(self);
		}
		return self;
	}

	pub fn deinit(self: *@This()) void {
		if (self.fi.deinit) |func| {
			func(self);
		}
		root.allocator.destroy(self);
	}

	pub fn render(self: *@This(), window: *root.UWindow) anyerror!void {
		std.debug.print("\n{*}\n", .{self});
		std.debug.print("bounds: {}\n", .{self.clamped_bounds});
		if (self.fi.render) |func| {
			try func(self, window);
		}
	}

	pub fn update(self: *@This(), space: UBounds, alignment: UAlign) anyerror!void {
		if (self.fi.update) |func| {
			try func(self, space, alignment);
		}
	}

	pub fn getChildren(self: *@This()) anyerror!std.ArrayList(*UWidget) {
		if (self.fi.getChildren) |func| {
			return try func(self);
		}
		return root.UError.MissingWidgetFunction;
	}
};

pub const UWidgetFI = struct {
	init: ?*const fn (self: *UWidget) anyerror!void = null,
	deinit: ?*const fn (self: *UWidget) void = null,
	render: ?*const fn (self: *UWidget, window: *root.UWindow) anyerror!void = renderWidget,
	update: ?*const fn (self: *UWidget, space: UBounds, alignment: UAlign) anyerror!void = updateWidget,
	getChildren: ?*const fn (self: *UWidget) anyerror!std.ArrayList(*UWidget) = null,
};

pub fn renderWidget(self: *UWidget, window: *root.UWindow) anyerror!void {
	const children = try self.getChildren();
	for (children.items) |child| {
		_ = try child.render(window);
	}
}

pub fn updateWidget(self: *UWidget, space: UBounds, alignment: UAlign) anyerror!void {
	const new_space = updateWidgetSelf(self, space, alignment);

	const children = try self.getChildren();
	for (children.items) |child| {
		_ = try child.update(new_space, alignment);
	}
}

pub fn updateWidgetSelf(self: *UWidget, space: UBounds, alignment: UAlign) UBounds {
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
