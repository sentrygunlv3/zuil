/// fill:
/// fills available space inside parent bounds
/// 
/// absolute:
/// ignores parent bounds
/// 
/// normal:
/// only follows parent bounds if available space is smaller than self bounds
pub const ZLayout = enum {
	fill,
	absolute,
	normal,

	pub fn default() @This() {
		return .normal;
	}
};

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

pub const ZBounds = struct {
	x: f32,
	y: f32,
	w: f32,
	h: f32,

	pub fn zero() @This() {
		return .{
			.x = 0,
			.y = 0,
			.w = 0,
			.h = 0,
		};
	}
};

pub const ZMargin = struct {
	top: f32,
	bottom: f32,
	left: f32,
	right: f32,

	pub fn zero() @This() {
		return .{
			.top = 0,
			.bottom = 0,
			.left = 0,
			.right = 0,
		};
	}
};
