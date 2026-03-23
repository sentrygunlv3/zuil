const std = @import("std");
const root = @import("root.zig");
const zrenderer = @import("renderer.zig");

pub const RenderCommandList = zrenderer.RenderCommandList;
pub const RenderCommand = zrenderer.RenderCommand;
pub const TextureParameter = zrenderer.TextureParameter;
pub const ShaderParameter = zrenderer.ShaderParameter;
pub const ZRenderer = zrenderer.ZRenderer;

pub const MeshHandle = ResourceHandle;
pub const TextureHandle = ResourceHandle;
pub const ShaderHandle = ResourceHandle;

pub const ResourceHandle = struct {
	resource: *anyopaque,

	pub fn deinit(self: *@This(), context: *root.ZContext) void {
		context.resourceRemoveUser(self) catch |e| {
			std.debug.print("resource: {}\n", .{e});
		};
	}
};

pub const LogType = enum(u8) {
	info = 0,
	warning,
	err,
	debug,
};

fn log_default(t: LogType, string: [*c]const u8) callconv(.c) void {
	if (@import("build_options").debug) std.debug.print("[{s}] {s}\n", .{@tagName(t), string});
}

pub const ZContext = struct {
	allocator: std.mem.Allocator,
	external: struct {
		log: *const fn (t: LogType, string: [*c]const u8) callconv(.c) void = log_default,
	},
	renderer: zrenderer.ZRenderer,

	freetype: root.ft.FT_Library = undefined,

	shaders: std.StringHashMap(ShaderHandle),

	fonts: std.StringHashMapUnmanaged(*root.font.ZFont),
	font_textures: std.AutoHashMap(*root.font.ZFont, TextureHandle),

	pub fn init(allocator: std.mem.Allocator, renderer: zrenderer.ZRenderer) !*@This() {
		const self = try allocator.create(@This());
		errdefer self.allocator.destroy(self);

		self.* = .{
			.allocator = allocator,
			.external = .{},
			.renderer = renderer,

			.shaders = .init(allocator),
			.fonts = .empty,
			.font_textures = .init(allocator),
		};
		errdefer self.shaders.deinit();
		errdefer self.fonts.deinit();
		errdefer self.font_textures.deinit();

		_ = root.ft.FT_Init_FreeType(&self.freetype);
		errdefer _ = root.ft.FT_Done_FreeType(self.freetype);

		return self;
	}

	pub fn lateInit(self: *@This()) !void {
		try self.renderer.init();
		errdefer self.renderer.deinit();
	}

	pub fn deinit(self: *@This()) void {
		self.renderer.deinit();
		_ = root.ft.FT_Done_FreeType(self.freetype);

		self.shaders.deinit();
		self.fonts.deinit(self.allocator);
		self.font_textures.deinit();

		self.allocator.destroy(self);
	}

	pub fn setLogCallback(self: *@This(), func: *const fn (t: LogType, string: [*c]const u8) void) void {
		self.external.log = func;
	}

	pub fn log(self: *@This(), t: LogType, comptime fmt: []const u8, args: anytype) void {
		var buffer: [256]u8 = undefined;
		const string = std.fmt.bufPrintZ(&buffer, fmt, args) catch return;
		self.external.log(t, string);
	}

	pub fn resourceRemoveUser(self: *@This(), resource: *ResourceHandle) anyerror!void {
		if (self.renderer.resourceRemoveUser) |func| {
			try func(resource);
			return;
		}
		return root.ZError.NotSupportedByBackend;
	}

	pub fn resourcesUpdate(self: *@This()) anyerror!void {
		if (self.renderer.resourcesUpdate) |func| {
			func();
			return;
		}
		return root.ZError.NotSupportedByBackend;
	}

	pub fn clip(self: *@This(), area: ?root.types.ZBounds) !void {
		if (self.renderer.clip) |func| {
			func(area);
			return;
		}
		return root.ZError.NotSupportedByBackend;
	}

	pub fn clear(self: *@This(), color: root.color.ZColor) !void {
		if (self.renderer.clear) |func| {
			func(color);
			return;
		}
		return root.ZError.NotSupportedByBackend;
	}

	pub fn renderCommands(self: *@This(), commands: *zrenderer.RenderCommandList) anyerror!void {
		if (self.renderer.renderCommands) |func| {
			try func(commands);
			return;
		}
		return root.ZError.NotSupportedByBackend;
	}

	pub fn createTexture(self: *@This(), bitmap: *root.ZBitmap) anyerror!TextureHandle {
		if (self.renderer.createTexture) |func| {
			return try func(bitmap);
		}
		return root.ZError.NotSupportedByBackend;
	}

	pub fn createShader(self: *@This(), v: []const u8, f: []const u8) !ShaderHandle {
		if (self.renderer.createShader) |func| {
			return try func(v, f);
		}
		return root.ZError.NotSupportedByBackend;
	}

	pub fn createMesh(self: *@This(), mesh: *const root.mesh.ZMesh) anyerror!MeshHandle {
		if (self.renderer.createMesh) |func| {
			return try func(mesh);
		}
		return root.ZError.NotSupportedByBackend;
	}

	pub fn getFontTexture(self: *@This(), context: *root.ZContext, font: *root.font.ZFont) !TextureHandle {
		if (self.font_textures.get(font)) |s| {
			return s;
		}
		var handle = try context.createTexture(&font.texture);
		errdefer context.resourceRemoveUser(&handle) catch {};
		try self.font_textures.put(font, handle);
		return handle;
	}

	pub fn getShader(self: *@This(), name: []const u8) !ShaderHandle {
		const handle = self.shaders.get(name);
		if (handle) |s| {
			return s;
		}
		return root.ZError.MissingShader;
	}

	pub fn registerShader(self: *@This(), context: *root.ZContext, name: []const u8, v: []const u8, f: []const u8) !void {
		const handle = try context.createShader(v, f);

		try self.shaders.put(name, handle);
	}
};
