const std = @import("std");
const root = @import("root.zig");

pub const Theme = struct {
	background: root.color.ZColor = .default,
	styles: std.StringHashMap(Style),

	pub const Style = struct {
		ptr: *anyopaque,
		func_deinit: *const fn (self: *anyopaque, alloc: std.mem.Allocator) void,
	};

	pub fn init(alloc: std.mem.Allocator) !*@This() {
		const self = try alloc.create(@This());
		self.* = .{
			.styles = .init(alloc),
		};
		return self;
	}

	pub fn deinit(self: *@This(), alloc: std.mem.Allocator) void {
		_ = alloc;
		self.styles.deinit();
	}

	pub fn put(self: *@This(), key: []const u8, style: Style) !void {
		try self.styles.put(key, style);
	}

	pub fn get(self: *const @This(), key: []const u8) ?*anyopaque {
		const style = self.styles.get(key) orelse return null;
		return style.ptr;
	}
};
