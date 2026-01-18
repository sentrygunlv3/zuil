const std = @import("std");
const root = @import("../root.zig");

pub const context = @import("context.zig");

const shader = root.shader;
const gl = root.gl;

pub const RenderCommandList = struct {
	allocator: std.mem.Allocator,
	commands: std.ArrayList(*root.renderer.RenderCommand),

	pub fn init(a: std.mem.Allocator) !@This() {
		return .{
			.allocator = a,
			.commands = try std.ArrayList(*root.renderer.RenderCommand).initCapacity(a, 16),
		};
	}

	pub fn append(self: *@This(), s: []const u8, p: []const ShaderParameter) !void {
		const item = try self.allocator.create(RenderCommand);

		const parameters = try self.allocator.alloc(ShaderParameter, p.len);
		@memcpy(parameters, p);

		item.* = RenderCommand{
			.shader = s,
			.parameters = parameters,
		};

		try self.commands.append(self.allocator, item);
	}
};

pub const RenderCommand = struct {
	shader: []const u8,
	parameters: []ShaderParameter,
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

pub fn clip(area: ?root.types.ZBounds) void {
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
}

pub fn clear(color: root.color.ZColor) void {
	const clear_color = [_]f32{color.r, color.g, color.b, color.a};
	root.gl.clearBufferfv(root.gl.COLOR, 0, &clear_color);
}

pub fn renderCommands(c: *context.RendererContext, commands: *root.renderer.RenderCommandList) anyerror!void {
	gl.bindVertexArray(c.vertex_arrays);

	gl.bindBuffer(gl.ARRAY_BUFFER, c.buffers);
	gl.bufferData(gl.ARRAY_BUFFER, vertices.len * @sizeOf(f32), &vertices, gl.STATIC_DRAW);

	gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, c.element_buffer);
	gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, indices.len * @sizeOf(u32), &indices, gl.STATIC_DRAW);

	gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
	gl.enableVertexAttribArray(0);

	gl.vertexAttribPointer(2, 2, root.gl.FLOAT, root.gl.FALSE, 4 * @sizeOf(f32), null);
	gl.enableVertexAttribArray(2);

	var current: u32 = 0;
	for (commands.commands.items) |command| {
		const shader_handle = try shader.getShader(c, command.shader);
		if (shader_handle.resource.type.shader.shader != current) {
			gl.useProgram(shader_handle.resource.type.shader.shader);
			current = shader_handle.resource.type.shader.shader;
		}

		for (command.parameters) |value| {
			switch (value.value) {
				.uniform2f => {
					gl.uniform2f(
						try shader_handle.resource.type.shader.getLocation(value.name),
						value.value.uniform2f.a,
						value.value.uniform2f.b
					);
				},
				.uniform4f => {
					gl.uniform4f(
						try shader_handle.resource.type.shader.getLocation(value.name),
						value.value.uniform4f.a,
						value.value.uniform4f.b,
						value.value.uniform4f.c,
						value.value.uniform4f.d
					);
				},
				.uniform1i => {
					gl.uniform1i(
						try shader_handle.resource.type.shader.getLocation(value.name),
						value.value.uniform1i
					);
				},
				.texture => {
					if (value.value.texture.resource.type != .texture) {
						continue;
					}

					gl.activeTexture(gl.TEXTURE0);
					gl.bindTexture(gl.TEXTURE_2D, value.value.texture.resource.type.texture);

					gl.uniform1i(
						try shader_handle.resource.type.shader.getLocation(value.name),
						0
					);
				},
			}
		}

		gl.drawElements(gl.TRIANGLES, 6, gl.UNSIGNED_INT, null);
	}
}
