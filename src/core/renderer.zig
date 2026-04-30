const std = @import("std");
const root = @import("root.zig");

pub const ZRenderer = struct {
	init: *const fn (alloc: std.mem.Allocator) anyerror!void,
	deinit: *const fn () void,
	resourceRemoveUser: *const fn (resource: *root.context.ResourceHandle) anyerror!void,
	resourcesUpdate: *const fn () void,
	clip: *const fn (area: ?root.types.ZBounds) void,
	clear: *const fn (color: root.color.ZColor) void,
	renderCommands: *const fn (commands: *RenderCommandList) anyerror!void,
	createTexture: *const fn (bitmap: *root.ZBitmap) anyerror!root.context.TextureHandle,
	createShader: *const fn (v: []const u8, f: []const u8) anyerror!root.context.ShaderHandle,
	createMesh: *const fn (mesh: *const root.mesh.ZMesh) anyerror!root.context.MeshHandle,
};

pub const RenderCommandList = struct {
	allocator: std.mem.Allocator,
	commands: std.ArrayList(RenderCommand),

	pub fn init(a: std.mem.Allocator) !@This() {
		return .{
			.allocator = a,
			.commands = try std.ArrayList(RenderCommand).initCapacity(a, 16),
		};
	}

	pub fn append(
		self: *@This(),
		shader: root.context.ShaderHandle,
		mesh: ?root.context.MeshHandle,
		texturers: []const TextureParameter,
		parameters: []const ShaderParameter
	) !void {
		const p = try self.allocator.alloc(ShaderParameter, parameters.len);
		@memcpy(p, parameters);
		const t = try self.allocator.alloc(TextureParameter, texturers.len);
		@memcpy(t, texturers);

		const item = RenderCommand{
			.shader = shader,
			.parameters = p,
			.textures = t,
			.mesh = mesh,
		};

		try self.commands.append(self.allocator, item);
	}
};

pub const RenderCommand = struct {
	shader: root.context.ShaderHandle,
	parameters: []ShaderParameter,
	mesh: ?root.context.ResourceHandle = null,
	textures: []TextureParameter,
};

pub const ShaderParameter = struct {
	name: []const u8,
	value: union(enum) {
		uniform1f: f32,
		uniform2f: struct {
			a: f32,
			b: f32,
		},
		uniform3f: struct {
			a: f32,
			b: f32,
			c: f32,
		},
		uniform4f: struct {
			a: f32,
			b: f32,
			c: f32,
			d: f32,
		},
		uniform1i: i32,
		uniform2i: struct {
			a: i32,
			b: i32,
		},
		uniform3i: struct {
			a: i32,
			b: i32,
			c: i32,
		},
		uniform4i: struct {
			a: i32,
			b: i32,
			c: i32,
			d: i32,
		},
	},
};

pub const TextureParameter = struct {
	slot: u32,
	texture: root.context.TextureHandle,
};
