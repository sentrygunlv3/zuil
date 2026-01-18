const std = @import("std");
const root = @import("../root.zig");
const gl = root.gl;

pub const context = @import("context.zig");

pub fn getShader(c: *context.RendererContext, name: []const u8) !context.ResourceHandle {
	const shader = c.shaders.get(name);
	if (shader) |s| {
		return s;
	}
	return root.ZError.MissingShader;
}

pub fn registerShader(c: *context.RendererContext, name: []const u8, v: []const u8, f: []const u8) !void {
	const vertex = try compileShader(gl.VERTEX_SHADER, v);
	const fragment = try compileShader(gl.FRAGMENT_SHADER, f);
	
	const program = gl.createProgram();
	gl.attachShader(program, vertex);
	gl.attachShader(program, fragment);
	gl.linkProgram(program);

	var status: i32 = 0;
	gl.getProgramiv(program, gl.LINK_STATUS, &status);
	if (status == 0) {
		return root.ZError.FailedToLinkShader;
	}

	gl.deleteShader(vertex);
	gl.deleteShader(fragment);

	const resource = try context.Resource.init(.{.shader = .{
		.shader = program,
	}}, false);
	errdefer resource.deinit();
	try c.resources.append(root.allocator, resource);

	try c.shaders.put(name, context.ResourceHandle.init(c, resource));
}

fn compileShader(shader_type: u32, source: []const u8) !u32 {
	const shader = gl.createShader(shader_type);
	gl.shaderSource(shader, 1, @ptrCast(&source), null);
	gl.compileShader(shader);
	var status: i32 = 0;
	gl.getShaderiv(shader, gl.COMPILE_STATUS, &status);
	if (status == 0) {
		return root.ZError.FailedToCompileShader;
	}
	return shader;
}

pub fn debugPrintAll(c: *context.RendererContext) void {
	var iterator = c.shaders.keyIterator();
	while (iterator.next()) |key| {
		std.debug.print("{s}\n", .{key.*});
	}
}
