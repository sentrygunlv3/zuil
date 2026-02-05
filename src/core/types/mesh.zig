const std = @import("std");

pub const ZMeshBuilder = struct {
	allocator: std.mem.Allocator,
	vertices: std.ArrayList(f32),
	indices: std.ArrayList(u32),

	pub fn init(allocator: std.mem.Allocator) !@This() {
		return .{
			.allocator = allocator,
			.vertices = try std.ArrayList(f32).initCapacity(allocator, 32),
			.indices = try std.ArrayList(u32).initCapacity(allocator, 16),
		};
	}

	pub fn deinit(self: *@This()) void {
		self.vertices.deinit(self.allocator);
		self.indices.deinit(self.allocator);
	}

	pub fn appendVertices(self: *@This(), v: []const f32) !void {
		try self.vertices.appendSlice(self.allocator, v);
	}

	pub fn appendIndices(self: *@This(), i: []const u32) !void {
		try self.indices.appendSlice(self.allocator, i);
	}

	pub fn build(self: *@This()) ZMesh {
		return .{
			.vertices = self.vertices.items,
			.indices = self.indices.items,
		};
	}
};

pub const ZMesh = struct {
	vertices: []const f32,
	indices: []const u32,

	pub fn default() @This() {
		return DefaultMesh;
	}
};

pub const DefaultMesh = ZMesh{
	.vertices = &[_]f32{
		// bottom left
		0, -1, 0, 1,
		// bottom right
		1, -1, 1, 1,
		// top right
		1, 0, 1, 0,
		// top left
		0, 0, 0, 0,
	},
	.indices = &[_]u32{
		0, 1, 2,
		0, 2, 3,
	},
};
