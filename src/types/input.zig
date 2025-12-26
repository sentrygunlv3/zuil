const std = @import("std");
const glfw = @import("glfw");

pub const UKey = enum(u32) {
	unknown = 0,
	a, b, c, d, e, f, g, h, i, j, k, l, m, n, o, p, q, r, s, t, u, v, w, x, y, z,
	num_0, num_1, num_2, num_3, num_4, num_5, num_6, num_7, num_8, num_9,

	fn_1, fn_2, fn_3, fn_4, fn_5, fn_6, fn_7, fn_8, fn_9, fn_10, fn_11, fn_12,
	fn_13, fn_14, fn_15, fn_16, fn_17, fn_18, fn_19, fn_20, fn_21, fn_22, fn_23, fn_24,

	numpad_0, numpad_1, numpad_2, numpad_3, numpad_4, numpad_5, numpad_6, numpad_7, numpad_8, numpad_9,

	left_shift, right_shift,
	left_control, right_control,
	left_alt, right_alt,
	left_super, right_super,

	pub fn isModifier(self: UKey) bool {
		return switch (self) {
			.left_shift, .right_shift,
			.left_control, .right_control,
			.left_alt, .right_alt,
			.left_super, .right_super => true,
			else => false,
		};
	}
};

pub const UMouseKey = enum(u32) {
	right,
	middle,
	left,
};

pub const UAction = enum(u16) {
	press,
	hold,
	release,
};

const UModifiers = packed struct {
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

pub const UKeyEvent = struct {
	key: UKey,
	modifiers: UModifiers,
	action: UAction,
	scan_code: u32,
};

pub const UMouseEvent = struct {
	key: UMouseKey,
	modifiers: UModifiers,
	action: UAction,
	x: f32,
	y: f32,
	global_x: f32,
	global_y: f32,
};

pub const UMouseMoveEvent = struct {
	x: f32,
	y: f32,
	global_x: f32,
	global_y: f32,
	distance_x: f32,
	distance_y: f32,
};

pub const UMouseWheelEvent = struct {
	modifiers: UModifiers,
	x: f32,
	y: f32,
	global_x: f32,
	global_y: f32,
	distance_x: f32,
	distance_y: f32,
};

pub const UEvent = union(enum) {
	key: UKeyEvent,
	mouse: UMouseEvent,
	mouse_move: UMouseMoveEvent,
	mouse_scroll: UMouseWheelEvent,
	focused: void,
	unfocused: void,
};
