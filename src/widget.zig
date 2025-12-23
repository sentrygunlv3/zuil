const std = @import("std");
const root = @import("root.zig");

/// fill:
/// fills available space inside parent bounds
/// 
/// absolute:
/// ignores parent bounds
/// 
/// normal:
/// only follows parent bounds if available space is smaller than self bounds
pub const ULayout = enum {
	fill,
	absolute,
	normal,

	pub fn default() @This() {
		return .normal;
	}
};

pub const UAlign = enum {
	topLeft,
	top,
	topRight,
	left,
	center,
	right,
	bottomLeft,
	bottom,
	bottomRight,

	pub fn default() @This() {
		return .topLeft;
	}
};

pub const UDirection = enum {
	horizontal,
	vertical,

	pub fn default() @This() {
		return .horizontal;
	}
};

pub const UBounds = struct {
	w: f32,
	h: f32,

	pub fn zero() @This() {
		return .{
			.w = 0,
			.h = 0,
		};
	}
};

pub const UPosition = struct {
	x: f32,
	y: f32,

	pub fn zero() @This() {
		return .{
			.x = 0,
			.y = 0,
		};
	}
};

pub const UWidget = struct {
	type_name: []const u8 = "UWidget",
	fi: UWidgetFI,
	parent: ?*UWidget = null,
	data: ?*anyopaque = null,
	// ---
	bounds: UBounds = UBounds.zero(),
	clamped_bounds: UBounds = UBounds.zero(),
	position: UPosition = UPosition.zero(),
	// ---
	content_alignment: UAlign = UAlign.default(),
	layout: ULayout = ULayout.normal,

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
		std.debug.print("pos: {}\n", .{self.position});
		if (self.fi.render) |func| {
			try func(self, window);
		}
	}

	pub fn update(self: *@This(), window: *root.UWindow) anyerror!void {
		if (self.fi.update) |func| {
			try func(self, window);
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
	update: ?*const fn (self: *UWidget, window: *root.UWindow) anyerror!void = updateWidget,
	getChildren: ?*const fn (self: *UWidget) anyerror!std.ArrayList(*UWidget) = null,
};

pub fn renderWidget(self: *UWidget, window: *root.UWindow) anyerror!void {
	const children = try self.getChildren();
	for (children.items) |child| {
		_ = try child.render(window);
	}
}

pub fn updateWidget(self: *UWidget, window: *root.UWindow) anyerror!void {
	var space = UBounds.zero();
	var self_alignment = UAlign.default();
	var position = UPosition.zero();

	if (self.parent) |parent| {
		space = parent.clamped_bounds;
		self_alignment = parent.content_alignment;
		position = parent.position;
	} else {
		space = window.getSize();
		self_alignment = window.content_alignment;
	}

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

	var offset = UPosition.zero();

	switch (self_alignment) {
		.topLeft => {},
		.top => {
			offset.x = (space.w - self.clamped_bounds.w) * 0.5;
		},
		.topRight => {
			offset.x = space.w - self.clamped_bounds.w;
		},
		.left => {
			offset.y = (space.h - self.clamped_bounds.h) * 0.5;
		},
		.center => {
			offset.x = (space.w - self.clamped_bounds.w) * 0.5;
			offset.y = (space.h - self.clamped_bounds.h) * 0.5;
		},
		.right => {
			offset.x = space.w - self.clamped_bounds.w;
			offset.y = (space.h - self.clamped_bounds.h) * 0.5;
		},
		.bottomLeft => {
			offset.y = space.h - self.clamped_bounds.h;
		},
		.bottom => {
			offset.x = (space.w - self.clamped_bounds.w) * 0.5;
			offset.y = space.h - self.clamped_bounds.h;
		},
		.bottomRight => {
			offset.x = space.w - self.clamped_bounds.w;
			offset.y = space.h - self.clamped_bounds.h;
		},
	}

	self.position = .{
		.x = position.x + offset.x,
		.y = position.y + offset.y,
	};

	const children = try self.getChildren();
	for (children.items) |child| {
		_ = try child.update(window);
	}
}
