const std = @import("std");

pub const ZKey = enum(u32) {
	unknown = 0,
	a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z,
	num_0, num_1, num_2, num_3, num_4, num_5, num_6, num_7, num_8, num_9,

	space,

	numpad_0, numpad_1, numpad_2, numpad_3, numpad_4, numpad_5, numpad_6, numpad_7, numpad_8, numpad_9,

	fn_1, fn_2, fn_3, fn_4, fn_5, fn_6, fn_7, fn_8, fn_9, fn_10, fn_11, fn_12,
	fn_13, fn_14, fn_15, fn_16, fn_17, fn_18, fn_19, fn_20, fn_21, fn_22, fn_23, fn_24,

	left_shift, right_shift,
	left_control, right_control,
	left_alt, right_alt,
	left_super, right_super,

	pub fn isModifier(self: ZKey) bool {
		return switch (self) {
			.left_shift, .right_shift,
			.left_control, .right_control,
			.left_alt, .right_alt,
			.left_super, .right_super => true,
			else => false,
		};
	}
};

pub const ZMouseKey = enum(u32) {
	right,
	middle,
	left,
	four,
	five,
	six,
	seven,
	eight,
};

pub const ZAction = enum(u16) {
	press,
	hold,
	release,
};

pub const ZModifiers = packed struct {
	left_shift: bool = false,
	right_shift: bool = false,
	left_control: bool = false,
	right_control: bool = false,
	left_alt: bool = false,
	right_alt: bool = false,
	left_super: bool = false,
	right_super: bool = false,
	caps: bool = false,
	num: bool = false,
	_: i6 = 0,
};

pub const ZKeyEvent = struct {
	key: ZKey,
	modifiers: ZModifiers,
	action: ZAction,
	scan_code: i32,
};

pub const ZMouseEvent = struct {
	key: ZMouseKey,
	modifiers: ZModifiers,
	action: ZAction,
	x: f32,
	y: f32,
};

pub const ZMouseMoveEvent = struct {
	x: f32,
	y: f32,
	distance_x: f32,
	distance_y: f32,
};

pub const ZMouseWheelEvent = struct {
	modifiers: ZModifiers,
	x: f32,
	y: f32,
	distance_x: f32,
	distance_y: f32,
};

pub const ZEvent = union(enum) {
	key: ZKeyEvent,
	mouse: ZMouseEvent,
	mouse_move: ZMouseMoveEvent,
	mouse_scroll: ZMouseWheelEvent,
	focused: void,
	unfocused: void,
};
