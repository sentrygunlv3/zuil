const std = @import("std");
const root = @import("../root.zig");

pub const ZBitmap = struct {
	data: [] u8,
	w: u32,
	h: u32,
	format: Format = .RGBA,

	pub const Format = enum {
		R,
		RG,
		RGB,
		RGBA,
		BGRA,
	};

	pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
		allocator.free(self.data);
	}
};
