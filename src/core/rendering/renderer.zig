const std = @import("std");
const root = @import("../root.zig");

const shader = root.shader;
const gl = root.gl;

const vertices = [_]f32{
	// bottom left
	0, -1, 0, 1,
	// bottom right
	1, -1, 1, 1,
	// top right
	1, 0, 1, 0,
	// top left
	0, 0, 0, 0,
};

pub const indices = [_]u32{
	0, 1, 2,
	0, 2, 3,
};

pub const RenderCommand = struct {
	shader: u32,
	parameters: []const ShaderParameter,
};

pub const ShaderParameter = struct {
	name: []const u8,
	value: union(enum) {
		uniform2f: struct {
			a: f32,
			b: f32,
		},
		uniform4f: struct {
			a: f32,
			b: f32,
			c: f32,
			d: f32,
		},
		uniform1i: i32,
		texture: *root.ZBitmap,
	}
};

var vertex_arrays: u32 = 0;
var buffers: u32 = 0;
var element_buffer: u32 = 0;

pub fn init() void {
	root.gl.genVertexArrays(1, &vertex_arrays);
	root.gl.genBuffers(1, &buffers);
	root.gl.genBuffers(1, &element_buffer);

	root.gl.enable(root.gl.BLEND);
	root.gl.blendFunc(root.gl.SRC_ALPHA, root.gl.ONE_MINUS_SRC_ALPHA);
}

pub fn deinit() void {
	root.gl.deleteVertexArrays(1, &vertex_arrays);
	root.gl.deleteBuffers(1, &buffers);
	root.gl.deleteBuffers(1, &element_buffer);
}

pub fn renderCommand(command: RenderCommand) anyerror!void {
	var textures = try std.ArrayList(u32).initCapacity(root.allocator, 0);

	gl.useProgram(command.shader);

	gl.bindVertexArray(vertex_arrays);

	gl.bindBuffer(gl.ARRAY_BUFFER, buffers);
	gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.STATIC_DRAW);

	gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, element_buffer);
	gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, gl.STATIC_DRAW);

	gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
	gl.enableVertexAttribArray(0);

	gl.vertexAttribPointer(2, 2, root.gl.FLOAT, root.gl.FALSE, 4 * @sizeOf(f32), null);
	gl.enableVertexAttribArray(2);

	for (command.parameters) |value| {
		switch (value.value) {
			.uniform2f => {
				const loc = gl.getUniformLocation(command.shader, value.name.ptr);
				gl.uniform2f(
					loc,
					value.value.uniform2f.a,
					value.value.uniform2f.b
				);
			},
			.uniform4f => {
				const loc = gl.getUniformLocation(command.shader, value.name.ptr);
				gl.uniform4f(
					loc,
					value.value.uniform4f.a,
					value.value.uniform4f.b,
					value.value.uniform4f.c,
					value.value.uniform4f.d
				);
			},
			.uniform1i => {
				const loc = gl.getUniformLocation(command.shader, value.name.ptr);
				gl.uniform1i(loc, value.value.uniform1i);
			},
			.texture => {
				var texture: u32 = 0;

				root.gl.genTextures(1, &texture);
				root.gl.activeTexture(root.gl.TEXTURE0);
				root.gl.bindTexture(root.gl.TEXTURE_2D, texture);
				root.gl.texParameteri(root.gl.TEXTURE_2D, root.gl.TEXTURE_MIN_FILTER, root.gl.NEAREST);
				root.gl.texParameteri(root.gl.TEXTURE_2D, root.gl.TEXTURE_MAG_FILTER, root.gl.NEAREST);
				root.gl.texImage2D(
					root.gl.TEXTURE_2D,
					0,
					root.gl.RGBA,
					@intCast(value.value.texture.w),
					@intCast(value.value.texture.h),
					0,
					root.gl.BGRA,
					root.gl.UNSIGNED_BYTE,
					value.value.texture.data.ptr
				);
				try textures.append(root.allocator, texture);

				const loc = gl.getUniformLocation(command.shader, value.name.ptr);
				gl.uniform1i(loc, @intCast(texture));
			},
		}
	}

	gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);

	for (textures.items) |item| {
		root.gl.deleteTextures(1, &item);
	}
}
