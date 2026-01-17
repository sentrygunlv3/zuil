const std = @import("std");
const root = @import("../root.zig");

pub const context = @import("context.zig");

const shader = root.shader;
const gl = root.gl;

pub const RenderCommand = struct {
	shader: u32,
	parameters: []ShaderParameter,

	pub fn init(s: u32, p: []const ShaderParameter) !*@This() {
		const self = try root.allocator.create(@This());

		const parameters = try root.allocator.alloc(ShaderParameter, p.len);
		@memcpy(parameters, p);

		self.* = @This(){
			.shader = s,
			.parameters = parameters,
		};

		return self;
	}

	pub fn deinit(self: *@This()) void {
		root.allocator.free(self.parameters);
		root.allocator.destroy(self);
	}
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
		texture: *context.ResourceHandle,
	},
};

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

pub fn renderCommands(c: *context.RendererContext, commands: *std.ArrayList(*root.renderer.RenderCommand), area: ?root.types.ZBounds) anyerror!void {
	gl.bindVertexArray(c.vertex_arrays);

	gl.bindBuffer(gl.ARRAY_BUFFER, c.buffers);
	gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.STATIC_DRAW);

	gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, c.element_buffer);
	gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, gl.STATIC_DRAW);

	gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
	gl.enableVertexAttribArray(0);

	gl.vertexAttribPointer(2, 2, root.gl.FLOAT, root.gl.FALSE, 4 * @sizeOf(f32), null);
	gl.enableVertexAttribArray(2);

	if (area) |a| {
		gl.enable(gl.SCISSOR_TEST);
		gl.scissor(
			@intFromFloat(@floor(a.x)),
			@intFromFloat(@floor(a.y)),
			@intFromFloat(@floor(a.w)),
			@intFromFloat(@floor(a.h))
		);
	} else {
		gl.disable(gl.SCISSOR_TEST);
	}

	for (commands.items) |command| {
		gl.useProgram(command.shader);

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
					if (value.value.texture.resource.type != .texture) {
						continue;
					}

					gl.activeTexture(gl.TEXTURE0);
					gl.bindTexture(gl.TEXTURE_2D, value.value.texture.resource.type.texture);

					const loc = gl.getUniformLocation(command.shader, value.name.ptr);
					gl.uniform1i(loc, 0);
				},
			}
		}

		gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
	}
}
