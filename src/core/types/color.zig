pub const ZColor = struct {
	r: f32,
	g: f32,
	b: f32,
	a: f32,

	pub const default = @This(){
		.r = 1.0,
		.g = 1.0,
		.b = 1.0,
		.a = 1.0,
	};

	pub const RED: ZColor = .{ .r = 0.8, .g = 0.2, .b = 0.2, .a = 1};
	pub const GREEN: ZColor = .{ .r = 0.2, .g = 0.8, .b = 0.2, .a = 1};
	pub const BLUE: ZColor = .{ .r = 0.2, .g = 0.2, .b = 0.8, .a = 1};
	pub const WHITE: ZColor = .{ .r = 0.9, .g = 0.9, .b = 0.9, .a = 1};
	pub const GREY: ZColor = .{ .r = 0.4, .g = 0.4, .b = 0.4, .a = 1};
	pub const BLACK: ZColor = .{ .r = 0.1, .g = 0.1, .b = 0.1, .a = 1};
	pub const TRANSPARENT: ZColor = .{ .r = 0, .g = 0, .b = 0, .a = 0};

	pub fn rgb(r: f32, g: f32, b: f32) @This() {
		return .{
			.r = r,
			.g = g,
			.b = b,
			.a = 1.0,
		};
	}

	pub fn rgb256(r: u32, g: u32, b: u32) @This() {
		return .{
			.r = @as(f32, @floatFromInt(r)) / 255,
			.g = @as(f32, @floatFromInt(g)) / 255,
			.b = @as(f32, @floatFromInt(b)) / 255,
			.a = 1.0,
		};
	}
};
