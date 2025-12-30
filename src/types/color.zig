pub const RED: UColor = .{ .r = 0.8, .g = 0.2, .b = 0.2, .a = 1};
pub const GREEN: UColor = .{ .r = 0.2, .g = 0.8, .b = 0.2, .a = 1};
pub const BLUE: UColor = .{ .r = 0.2, .g = 0.2, .b = 0.8, .a = 1};
pub const WHITE: UColor = .{ .r = 0.9, .g = 0.9, .b = 0.9, .a = 1};
pub const GREY: UColor = .{ .r = 0.4, .g = 0.4, .b = 0.4, .a = 1};
pub const BLACK: UColor = .{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1};
pub const TRANSPARENT: UColor = .{ .r = 0, .g = 0, .b = 0, .a = 0};

pub const UColor = struct {
	r: f32,
	g: f32,
	b: f32,
	a: f32,

	pub fn default() @This() {
		return .{
			.r = 1.0,
			.g = 1.0,
			.b = 1.0,
			.a = 1.0,
		};
	}
};

pub fn rgb(r: f32, g: f32, b: f32) UColor {
	return .{
		.r = r,
		.g = g,
		.b = b,
		.a = 1.0,
	};
}

pub fn compare(a: UColor, b: UColor) bool {
	if (
		a.r == b.r and
		a.g == b.g and
		a.b == b.b and
		a.a == b.a
	) {
		return true;
	}
	return false;
}
