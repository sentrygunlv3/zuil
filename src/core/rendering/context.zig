const std = @import("std");
const root = @import("../root.zig");

const shader = root.shader;
const gl = root.gl;

pub const RenderContext = struct {
	shaders: std.StringHashMap(ResourceHandle),

	pub fn init() !*@This() {
		const self = try root.allocator.create(@This());
		self.* = @This(){
			.shaders = std.StringHashMap(ResourceHandle).init(root.allocator),
		};
		return self;
	}

	pub fn deinit(self: *@This()) void {
		self.shaders.deinit();
		root.allocator.destroy(self);
	}
};

pub const ResourceHandle = struct {
	resource: *anyopaque,

	pub fn deinit(self: *@This()) void {
		root.renderer.resourceRemoveUser(self) catch |e| {
			std.debug.print("resource: {}\n", .{e});
		};
	}
};

pub const RenderCommandList = struct {
	allocator: std.mem.Allocator,
	commands: std.ArrayList(*RenderCommand),

	pub fn init(a: std.mem.Allocator) !@This() {
		return .{
			.allocator = a,
			.commands = try std.ArrayList(*RenderCommand).initCapacity(a, 16),
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
		texture: *ResourceHandle,
	},
};
