const std = @import("std");
const renderer = @import("../shaders.zig").renderer;

const name = "font";

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
	\\        posIn.x,
	\\        posIn.y,
	\\        0.0, 1.0
	\\    );
	\\    texCoord = vec2(aTex.x, aTex.y);
	\\}
;

const fragment =
	\\#version 400 core
	\\
	\\in vec2 texCoord;
	\\
	\\uniform sampler2D tex0;
	\\uniform vec4 color;
	\\
	\\out vec4 FragColor;
	\\
	\\void main() {
	\\    vec4 mask = texture(tex0, texCoord);
	\\    FragColor = vec4(
	\\        color.r,
	\\        color.g,
	\\        color.b,
	\\        mask.r * color.a
	\\    );
	\\}
;

pub fn register(c: *renderer.context.RenderContext) void {
	c.registerShader(
		name,
		vertex,
		fragment
	) catch |e| {
		std.log.err("failed to register shader \"{s}\": {}", .{name, e});
	};
}
