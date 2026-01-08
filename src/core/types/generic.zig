const root = @import("../root.zig");

pub const ZAlign = enum {
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

pub const ZDirection = enum {
	horizontal,
	vertical,

	pub fn default() @This() {
		return .horizontal;
	}
};

/// area in real pixel
pub const ZBounds = struct {
	x: f32 = 0,
	y: f32 = 0,
	w: f32 = 0,
	h: f32 = 0,

	pub fn zero() @This() {
		return .{
			.x = 0,
			.y = 0,
			.w = 0,
			.h = 0,
		};
	}
};

pub const ZUnit = union(enum) {
	pixel: f32,
	percentage: f32,
	dp: f32,
	mm: f32,

	pub fn zero() @This() {
		return .{ .dp = 0 };
	}

	pub fn fill() @This() {
		return .{.percentage = 1};
	}

	/// returns raw value
	pub fn value(self: *@This()) f32 {
		return switch (self) {
			.pixel => self.pixel,
			.percentage => self.percentage,
			.dp => self.dp,
			.mm => self.mm,
		};
	}

	pub fn asPixel(self: *@This(), vertical: bool, space: ZBounds, window: *root.ZWindow) f32 {
		const dp_size = 0.16;

		var physical_size: f32 = 0;
		var space_size: f32 = 0;

		if (vertical) {
			physical_size = window.display_size.y;
			space_size = space.h;
		} else {
			physical_size = window.display_size.x;
			space_size = space.w;
		}

		return switch (self.*) {
			.pixel => self.pixel,
			.percentage => self.percentage * space_size,
			.dp => self.dp * dp_size * physical_size,
			.mm => self.mm * physical_size,
		};
	}
};

pub const ZPosition = struct {
	x: ZUnit,
	y: ZUnit,

	pub fn zero() @This() {
		return .{
			.x = .zero(),
			.y = .zero(),
		};
	}

	pub fn asBounds(self: *@This(), space: ZBounds, window: *root.ZWindow) ZBounds {
		return .{
			.x = self.x.asPixel(false, space, window),
			.y = self.y.asPixel(true, space, window),
		};
	}
};

pub const ZSize = struct {
	w: ZUnit,
	h: ZUnit,

	pub fn zero() @This() {
		return .{
			.w = .zero(),
			.h = .zero(),
		};
	}

	pub fn fill() @This() {
		return .{
			.w = .{.percentage = 1},
			.h = .{.percentage = 1},
		};
	}
 
	pub fn asBounds(self: *@This(), space: ZBounds, window: *root.ZWindow) ZBounds {
		return .{
			.w = self.w.asPixel(false, space, window),
			.h = self.h.asPixel(true, space, window),
		};
	}
};

pub const ZMargin = struct {
	top: ZUnit,
	bottom: ZUnit,
	left: ZUnit,
	right: ZUnit,

	pub fn zero() @This() {
		return .{
			.top = .zero(),
			.bottom = .zero(),
			.left = .zero(),
			.right = .zero(),
		};
	}

	pub fn new(size: f32) @This() {
		return .{
			.top = .{.dp = size},
			.bottom = .{.dp = size},
			.left = .{.dp = size},
			.right = .{.dp = size},
		};
	}

	pub fn asPixel(self: *@This(), space: ZBounds, window: *root.ZWindow) struct {
		top: f32,
		bottom: f32,
		left: f32,
		right: f32
	} {
		return .{
			.top = self.top.asPixel(true, space, window),
			.bottom = self.bottom.asPixel(true, space, window),
			.left = self.left.asPixel(false, space, window),
			.right = self.right.asPixel(false, space, window),
		};
	}
};
