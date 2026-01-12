const std = @import("std");
const shader = @import("../shaders.zig").shader;

const name = "container";

const vertex =
	\\#version 400 core
	\\
	\\layout (location = 0) in vec2 posIn;
	\\
	\\uniform vec2 pos;
	\\uniform vec2 size;
	\\
	\\void main() {
	\\    gl_Position = vec4(
	\\        (posIn.x * size.x - 1) + pos.x,
	\\        (posIn.y * size.y + 1) - pos.y,
	\\        0.0, 1.0
	\\    );
	\\}
;

const fragment =
	\\#version 400 core
	\\
	\\uniform vec4 color;
	\\
	\\out vec4 FragColor;
	\\
	\\void main() {
	\\    FragColor = color;
	\\}
;

pub fn register(c: *shader.context.RendererContext) void {
	shader.registerShader(
		c,
		name,
		vertex,
		fragment
	) catch |e| {
		std.log.err("failed to register shader \"{s}\": {}", .{name, e});
	};
}
