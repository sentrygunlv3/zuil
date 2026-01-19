const std = @import("std");
const root = @import("../root.zig");

pub const context = @import("context.zig");

const shader = root.shader;
const gl = root.gl;

pub const ZRenderFIOpengl = @import("backend/opengl.zig");

pub const ZRenderFI = struct {
	clip: ?*const fn (area: ?root.types.ZBounds) void = null,
	clear: ?*const fn (color: root.color.ZColor) void = null,
	renderCommands: ?*const fn (c: *context.RendererContext, commands: *root.renderer.RenderCommandList) anyerror!void = null,
};

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

pub fn clip(area: ?root.types.ZBounds) !void {
	if (root.render_fi.clip) |func| {
		func(area);
		return;
	}
	return root.ZError.NotSupportedByBackend;
}

pub fn clear(color: root.color.ZColor) !void {
	if (root.render_fi.clear) |func| {
		func(color);
		return;
	}
	return root.ZError.NotSupportedByBackend;
}

pub fn renderCommands(c: *context.RendererContext, commands: *root.renderer.RenderCommandList) anyerror!void {
	if (root.render_fi.renderCommands) |func| {
		try func(c, commands);
		return;
	}
	return root.ZError.NotSupportedByBackend;
}
