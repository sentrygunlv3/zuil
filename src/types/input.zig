const std = @import("std");
const glfw = @import("glfw");

pub const UKey = enum(u32) {
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

	pub fn isModifier(self: UKey) bool {
		return switch (self) {
			.left_shift, .right_shift,
			.left_control, .right_control,
			.left_alt, .right_alt,
			.left_super, .right_super => true,
			else => false,
		};
	}

	pub fn fromGlfw(key: glfw.Key) @This() {
		return switch (key) {
			.unknown => .unknown,
			.a => .a,
			.b => .b,
			.c => .c,
			.d => .d,
			.e => .e,
			.f => .f,
			.g => .g,
			.h => .h,
			.i => .i,
			.j => .j,
			.k => .k,
			.l => .l,
			.m => .m,
			.n => .n,
			.o => .o,
			.p => .p,
			.q => .q,
			.r => .r,
			.s => .s,
			.t => .t,
			.u => .u,
			.v => .v,
			.w => .w,
			.x => .x,
			.y => .y,
			.z => .z,
			.zero => .num_0,
			.one => .num_1,
			.two => .num_2,
			.three => .num_3,
			.four => .num_4,
			.five => .num_5,
			.six => .num_6,
			.seven => .num_7,
			.eight => .num_8,
			.nine => .num_9,
			.space => .space,
			.kp_0 => .numpad_0,
			.kp_1 => .numpad_1,
			.kp_2 => .numpad_2,
			.kp_3 => .numpad_3,
			.kp_4 => .numpad_4,
			.kp_5 => .numpad_5,
			.kp_6 => .numpad_6,
			.kp_7 => .numpad_7,
			.kp_8 => .numpad_8,
			.kp_9 => .numpad_9,
			.F1 => .fn_1,
			.F2 => .fn_2,
			.F3 => .fn_3,
			.F4 => .fn_4,
			.F5 => .fn_5,
			.F6 => .fn_6,
			.F7 => .fn_7,
			.F8 => .fn_8,
			.F9 => .fn_9,
			.F10 => .fn_10,
			.F11 => .fn_11,
			.F12 => .fn_12,
			.F13 => .fn_13,
			.F14 => .fn_14,
			.F15 => .fn_15,
			.F16 => .fn_16,
			.F17 => .fn_17,
			.F18 => .fn_18,
			.F19 => .fn_19,
			.F20 => .fn_20,
			.F21 => .fn_21,
			.F22 => .fn_22,
			.F23 => .fn_23,
			.F24 => .fn_24,
			.left_shift => .left_shift,
			.right_shift => .right_shift,
			.left_control => .left_control,
			.right_control => .right_control,
			.left_alt => .left_alt,
			.right_alt => .right_alt,
			.left_super => .left_super,
			.right_super => .right_super,
			else => .unknown,
		};
	}
};

pub const UMouseKey = enum(u32) {
	right,
	middle,
	left,
	four,
	five,
	six,
	seven,
	eight,

	pub fn fromGlfw(action: glfw.MouseButton) @This() {
		return switch (action) {
			.right => .right,
			.middle => .middle,
			.left => .left,
			.four => .four,
			.five => .five,
			.six => .six,
			.seven => .seven,
			.eight => .eight,
		};
	}
};

pub const UAction = enum(u16) {
	press,
	hold,
	release,

	pub fn fromGlfw(action: glfw.Action) @This() {
		return switch (action) {
			.press => .press,
			.repeat => .hold,
			.release => .release,
		};
	}
};

pub const UModifiers = packed struct {
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
	scan_code: i32,
};

pub const UMouseEvent = struct {
	key: UMouseKey,
	modifiers: UModifiers,
	action: UAction,
	x: f32,
	y: f32,
};

pub const UMouseMoveEvent = struct {
	x: f32,
	y: f32,
	distance_x: f32,
	distance_y: f32,
};

pub const UMouseWheelEvent = struct {
	modifiers: UModifiers,
	x: f32,
	y: f32,
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
