const std = @import("std");
const root = @import("../root.zig");

const gl = root.gl;
const ZError = root.errors.ZError;

pub const renderer = @import("renderer.zig");

pub const RenderContext = struct {
	shaders: std.StringHashMap(ResourceHandle),
	font_textures: std.AutoHashMap(*root.font.ZFont, ResourceHandle),

	pub fn init() !*@This() {
		const self = try root.allocator.create(@This());
		self.* = @This(){
			.shaders = std.StringHashMap(ResourceHandle).init(root.allocator),
			.font_textures = std.AutoHashMap(*root.font.ZFont, ResourceHandle).init(root.allocator),
		};
		return self;
	}

	pub fn deinit(self: *@This()) void {
		self.shaders.deinit();
		self.font_textures.deinit();
		root.allocator.destroy(self);
	}

	pub fn getFontTexture(self: *@This(), font: *root.font.ZFont) !ResourceHandle {
		var handle = self.font_textures.get(font);
		if (handle) |s| {
			return s;
		}
		handle = try renderer.createTexture(&font.texture);
		errdefer renderer.resourceRemoveUser(&handle.?) catch {};
		try self.font_textures.put(font, handle.?);
		return handle.?;
	}

	pub fn getShader(self: *@This(), name: []const u8) !ResourceHandle {
		const handle = self.shaders.get(name);
		if (handle) |s| {
			return s;
		}
		return ZError.MissingShader;
	}

	pub fn registerShader(self: *@This(), name: []const u8, v: []const u8, f: []const u8) !void {
		const handle = try root.renderer.createShader(v, f);

		try self.shaders.put(name, handle);
	}

	pub fn debugPrintAll(self: *@This(), ) void {
		var iterator = self.shaders.keyIterator();
		while (iterator.next()) |key| {
			std.debug.print("{s}\n", .{key.*});
		}
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
	commands: std.ArrayList(RenderCommand),

	pub fn init(a: std.mem.Allocator) !@This() {
		return .{
			.allocator = a,
			.commands = try std.ArrayList(RenderCommand).initCapacity(a, 16),
		};
	}

	pub fn append(self: *@This(), s: []const u8, p: []const ShaderParameter) !void {
		const parameters = try self.allocator.alloc(ShaderParameter, p.len);
		@memcpy(parameters, p);

		const item = RenderCommand{
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
		texture: ResourceHandle,
	},
};
