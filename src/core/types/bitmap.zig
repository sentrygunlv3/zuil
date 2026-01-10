const root = @import("../root.zig");

pub const ZBitmap = struct {
	data: []const u8,
	w: u32,
	h: u32,

	pub fn deinit(self: *@This()) void {
		root.allocator.free(self.data);
	}
};
