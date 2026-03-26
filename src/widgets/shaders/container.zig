const std = @import("std");
const root = @import("../widgets.zig");

const name = "container";

const vertex =
	\\#version 400 core
	\\
	\\layout (location = 0) in vec2 posIn;
	\\
	\\uniform vec2 pos;
	\\uniform vec2 size;
	\\
	\\out vec2 position;
	\\
	\\void main() {
	\\    position = posIn;
	\\    gl_Position = vec4(
	\\        (posIn.x * size.x - 1) + pos.x,
	\\        (1 - posIn.y * size.y) - pos.y,
	\\        0.0, 1.0
	\\    );
	\\}
;

// TODO: probably not the best shader
// a better one could have different radius per corner and a border
const fragment =
	\\#version 400 core
	\\
	\\uniform vec2 size;
	\\uniform vec2 screenSize;
	\\uniform vec4 color;
	\\uniform float radius;
	\\
	\\in vec2 position;
	\\out vec4 FragColor;
	\\
	\\void main() {
	\\    vec2 d = abs((position - 0.5) * size * screenSize) - (size * screenSize) * 0.5 + radius;
	\\    float distance = min(max(d.x, d.y), 0.0) + length(max(d, 0.0)) - radius;
	\\    float nDistance = distance / min(screenSize.x, screenSize.y);
	\\
	\\    float alpha = smoothstep(0.5, -0.5, nDistance / fwidth(nDistance));
	\\
	\\    if (alpha <= 0.0) {
	\\        discard;
	\\    }
	\\    FragColor = vec4(
	\\        color.rgb,
	\\        color.a * alpha
	\\    );
	\\}
;

pub fn register(c: *root.zuil.ZContext) void {
	c.registerShader(
		c,
		name,
		vertex,
		fragment
	) catch |e| {
		std.log.err("failed to register shader \"{s}\": {}", .{name, e});
	};
}
