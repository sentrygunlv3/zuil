const std = @import("std");
const root = @import("root.zig");

/// this will become a painter api type system but currently just uses the old ZRenderer system
pub const ZPainter = struct {
	ptr: *anyopaque,
	vtable: *const VTable,

	pub const VTable = struct {
		resourceRemoveUser: *const fn (self: *anyopaque, resource: root.context.ResourceHandle) anyerror!void,
		resourcesUpdate: *const fn (self: *anyopaque, ) void,

		renderBegin: *const fn (self: *anyopaque) void,
		addCommand: *const fn (self: *anyopaque, command: RenderCommand) anyerror!void,
		renderCommands: *const fn (self: *anyopaque) anyerror!void,
		renderEnd: *const fn (self: *anyopaque) void,

		clip: *const fn (self: *anyopaque, area: ?root.types.ZBounds, bounds: root.types.ZBounds) void,
		clear: *const fn (self: *anyopaque, color: root.color.ZColor) void,
		createTexture: *const fn (self: *anyopaque, bitmap: *root.ZBitmap) anyerror!root.context.TextureHandle,
		createMesh: *const fn (self: *anyopaque, mesh: *const root.mesh.ZMesh) anyerror!root.context.MeshHandle,
	};

	pub const Material = enum {
		container,
		bitmap,
		font,
	};

	pub fn cast(self: *@This(), comptime T: type) ?*T {
		if (self.vtable != &T.vtable) return null;
		return @as(*T, @alignCast(@ptrCast(self.ptr)));
	}

	pub fn resourceRemoveUser(self: *@This(), resource: root.context.ResourceHandle) anyerror!void {
		try self.vtable.resourceRemoveUser(self.ptr, resource);
	}

	pub fn resourcesUpdate(self: *@This()) void {
		self.vtable.resourcesUpdate(self.ptr);
	}

	pub fn renderBegin(self: *@This()) void {
		self.vtable.renderBegin(self.ptr);
	}

	pub fn addCommand(
		self: *@This(),
		allocator: std.mem.Allocator,
		shader: Material,
		mesh: ?root.context.MeshHandle,
		texturers: []const TextureParameter,
		parameters: []const ShaderParameter
	) !void {
		const p = try allocator.alloc(ShaderParameter, parameters.len);
		errdefer allocator.free(p);
		@memcpy(p, parameters);

		const t = try allocator.alloc(TextureParameter, texturers.len);
		errdefer allocator.free(t);
		@memcpy(t, texturers);

		const item = RenderCommand{
			.shader = shader,
			.parameters = p,
			.textures = t,
			.mesh = mesh,
		};

		try self.vtable.addCommand(self.ptr, item);
	}

	pub fn renderCommands(self: *@This()) anyerror!void {
		try self.vtable.renderCommands(self.ptr);
	}

	pub fn renderEnd(self: *@This()) void {
		self.vtable.renderEnd(self.ptr);
	}

	pub fn clip(self: *@This(), area: ?root.types.ZBounds, bounds: root.types.ZBounds) void {
		self.vtable.clip(self.ptr, area, bounds);
	}

	pub fn clear(self: *@This(), color: root.color.ZColor) void {
		self.vtable.clear(self.ptr, color);
	}

	pub fn createTexture(self: *@This(), bitmap: *root.ZBitmap) anyerror!root.context.TextureHandle {
		return try self.vtable.createTexture(self.ptr, bitmap);
	}

	pub fn createMesh(self: *@This(), mesh: *const root.mesh.ZMesh) anyerror!root.context.MeshHandle {
		return try self.vtable.createMesh(self.ptr, mesh);
	}
};

pub const RenderCommand = struct {
	shader: ZPainter.Material,
	parameters: []ShaderParameter,
	mesh: ?root.context.MeshHandle = null,
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
