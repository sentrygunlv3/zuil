const std = @import("std");
const root = @import("root.zig");
const gl = root.gl;

var shaders: std.StringHashMap(u32) = undefined;

pub fn init(allocator: std.mem.Allocator) void {
	shaders = std.StringHashMap(u32).init(allocator);

	@import("shaders/container.zig").register();
}

pub fn getShader(name: []const u8) !u32 {
	const shader = shaders.get(name);
	if (shader) |s| {
		return s;
	}
	return root.UError.MissingShader;
}

pub fn registerShader(name: []const u8, v: []const u8, f: []const u8) !void {
	const vertex = try compileShader(gl.VERTEX_SHADER, v);
	const fragment = try compileShader(gl.FRAGMENT_SHADER, f);
	
	const program = gl.createProgram();
	gl.attachShader(program, vertex);
	gl.attachShader(program, fragment);
	gl.linkProgram(program);

	var status: i32 = 0;
	gl.getProgramiv(program, gl.LINK_STATUS, &status);
	if (status == 0) {
		return root.UError.FailedToLinkShader;
	}

	gl.deleteShader(vertex);
	gl.deleteShader(fragment);

	try shaders.put(name, program);
}

fn compileShader(shader_type: u32, source: []const u8) !u32 {
	const shader = gl.createShader(shader_type);
	gl.shaderSource(shader, 1, @ptrCast(&source), null);
	gl.compileShader(shader);
	var status: i32 = 0;
	gl.getShaderiv(shader, gl.COMPILE_STATUS, &status);
	if (status == 0) {
		return root.UError.FailedToCompileShader;
	}
	return shader;
}

pub fn debugPrintAll() void {
	var iterator = shaders.keyIterator();
	while (iterator.next()) |key| {
		std.debug.print("{s}\n", .{key.*});
	}
}
