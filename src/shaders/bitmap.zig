const std = @import("std");
const shader = @import("../shaders.zig").shader;

const name = "bitmap";

const vertex =
	\\#version 400 core
	\\
	\\layout (location = 0) in vec2 posIn;
	\\layout (location = 2) in vec2 aTex;
	\\
	\\uniform vec2 pos;
	\\uniform vec2 size;
	\\
	\\out vec2 texCoord;
	\\
	\\void main() {
	\\    gl_Position = vec4(
	\\        (posIn.x * size.x - 1) + pos.x,
	\\        (posIn.y * size.y + 1) - pos.y,
	\\        0.0, 1.0
	\\    );
	\\    texCoord = vec2(aTex.x, 1.0 - aTex.y);
	\\}
;

const fragment =
	\\#version 400 core
	\\
	\\in vec2 texCoord;
	\\
	\\uniform sampler2D tex0;
	\\
	\\out vec4 FragColor;
	\\
	\\void main() {
	\\    FragColor = texture(tex0, texCoord);
	\\}
;

pub fn register(c: *shader.context.RenderContext) void {
	shader.registerShader(
		c,
		name,
		vertex,
		fragment
	) catch |e| {
		std.log.err("failed to register shader \"{s}\": {}", .{name, e});
	};
}
