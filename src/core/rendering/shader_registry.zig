const std = @import("std");
const root = @import("../root.zig");
const gl = root.gl;

pub const context = @import("context.zig");

pub fn getShader(c: *context.RenderContext, name: []const u8) !context.ResourceHandle {
	const shader = c.shaders.get(name);
	if (shader) |s| {
		return s;
	}
	return root.ZError.MissingShader;
}

pub fn registerShader(c: *context.RenderContext, name: []const u8, v: []const u8, f: []const u8) !void {
	const handle = try root.renderer.createShader(v, f);

	try c.shaders.put(name, handle);
}

pub fn debugPrintAll(c: *context.RenderContext, ) void {
	var iterator = c.shaders.keyIterator();
	while (iterator.next()) |key| {
		std.debug.print("{s}\n", .{key.*});
	}
}
