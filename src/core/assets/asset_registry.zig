const std = @import("std");
const root = @import("../root.zig");
const ZAsset = root.ZAsset;

var assets: std.StringHashMap(ZAsset) = undefined;

pub fn init() void {
	assets = std.StringHashMap(ZAsset).init(root.allocator);
}

pub fn deinit() void {
	assets.deinit();
}

pub fn getAsset(name: []const u8) !ZAsset {
	const asset = assets.get(name);
	if (asset) |a| {
		return a;
	}
	return root.errors.ZError.MissingAsset;
}

pub fn registerAsset(name: []const u8, asset: ZAsset) !void {
	try assets.put(name, asset);
}

pub fn registerAssetComptime(comptime path: []const u8, comptime file: []const u8, comptime t: ZAsset.Type) !void {
	try assets.put(path, .{
		.data = .{ .compile_time = .{
			.ptr = file.ptr,
			.len = file.len,
		}},
		.type = t,
	});
}

pub fn debugPrintAll() void {
	var iterator = assets.keyIterator();
	while (iterator.next()) |key| {
		std.debug.print("{s}\n", .{key.*});
	}
}
