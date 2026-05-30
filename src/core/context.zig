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
			context.log(.err, "resource ({*}) {}", .{self, e});
		};
	}
};

pub const LogType = enum(u8) {
	info = 0,
	warning,
	err,
	debug,
};

fn log_default(t: LogType, string: []const u8) void {
	// https://ss64.com/nt/syntax-ansi.html
	switch (t) {
		.debug => {
			if (@import("builtin").mode == std.builtin.OptimizeMode.Debug) {
				std.debug.print("\u{001b}[102m\u{001b}[30m[{s:7}]\u{001b}[0m {s}\n", .{@tagName(t), string});
			}
		},
		.err => {
			std.debug.print("\u{001b}[41m\u{001b}[30m[{s:7}]\u{001b}[0m {s}\n", .{"error", string});
		},
		.warning => {
			std.debug.print("\u{001b}[43m\u{001b}[30m[{s:7}]\u{001b}[0m {s}\n", .{@tagName(t), string});
		},
		.info => {
			std.debug.print("\u{001b}[104m\u{001b}[30m[{s:7}]\u{001b}[0m {s}\n", .{@tagName(t), string});
		},
	}
}

pub const ZContext = struct {
	allocator: std.mem.Allocator,
	external: struct {
		log: *const fn (t: LogType, string: []const u8) void = log_default,
	},
	renderer: zrenderer.ZRenderer,

	theme: *root.Theme,

	subcontext_hashmap: std.StringHashMap(Subcontext),

	shaders: std.StringHashMap(ShaderHandle),

	pub const Subcontext = struct {
		ptr: *anyopaque,
		func_deinit: *const fn (self: *anyopaque, context: *ZContext) void,
	};

	pub fn init(allocator: std.mem.Allocator, renderer: zrenderer.ZRenderer, theme: *root.Theme) !*@This() {
		const self = try allocator.create(@This());
		errdefer self.allocator.destroy(self);

		self.* = .{
			.allocator = allocator,
			.external = .{},
			.renderer = renderer,
			.theme = theme,
			.subcontext_hashmap = .init(allocator),

			.shaders = .init(allocator),
		};
		errdefer self.subcontext_hashmap.deinit();
		errdefer self.shaders.deinit();

		return self;
	}

	pub fn lateInit(self: *@This()) !void {
		try self.renderer.init(self.allocator);
		errdefer self.renderer.deinit();
	}

	pub fn deinit(self: *@This()) void {
		var it = self.subcontext_hashmap.valueIterator();
		while (it.next()) |s| {
			s.func_deinit(s.ptr, self);
		}

		self.subcontext_hashmap.deinit();

		var shader_it = self.shaders.iterator();
		while (shader_it.next()) |entry| {
			self.renderer.resourceRemoveUser(entry.value_ptr) catch |e| {
				self.log(.err, "failed to deinit shader: {}", .{e});
			};
		}
		self.shaders.deinit();

		self.renderer.resourcesUpdate();
		self.renderer.deinit();

		self.allocator.destroy(self);
	}

	pub fn setLogCallback(self: *@This(), func: *const fn (t: LogType, string: []const u8) void) void {
		self.external.log = func;
	}

	pub fn log(self: *@This(), t: LogType, comptime fmt: []const u8, args: anytype) void {
		var buffer: [256]u8 = undefined;
		const string = std.fmt.bufPrintZ(&buffer, fmt, args) catch return;
		self.external.log(t, string);
	}

	pub fn resourceRemoveUser(self: *@This(), resource: *ResourceHandle) anyerror!void {
		try self.renderer.resourceRemoveUser(resource);
	}

	pub fn resourcesUpdate(self: *@This()) void {
		self.renderer.resourcesUpdate();
	}

	pub fn clip(self: *@This(), area: ?root.types.ZBounds) void {
		self.renderer.clip(area);
	}

	pub fn clear(self: *@This(), color: root.color.ZColor) void {
		self.renderer.clear(color);
	}

	pub fn renderCommands(self: *@This(), commands: *zrenderer.RenderCommandList) anyerror!void {
		try self.renderer.renderCommands(commands);
	}

	pub fn createTexture(self: *@This(), bitmap: *root.ZBitmap) anyerror!TextureHandle {
		return try self.renderer.createTexture(bitmap);
	}

	pub fn createShader(self: *@This(), v: []const u8, f: []const u8) !ShaderHandle {
		return try self.renderer.createShader(v, f);
	}

	pub fn createMesh(self: *@This(), mesh: *const root.mesh.ZMesh) anyerror!MeshHandle {
		return try self.renderer.createMesh(mesh);
	}

	pub fn getShader(self: *@This(), name: []const u8) !ShaderHandle {
		const handle = self.shaders.get(name);
		if (handle) |s| {
			return s;
		}
		return root.ZError.MissingShader;
	}

	pub fn registerShader(self: *@This(), context: *@This(), name: []const u8, v: []const u8, f: []const u8) !void {
		const handle = try context.createShader(v, f);

		try self.shaders.put(name, handle);
	}

	pub fn putSubcontext(self: *@This(), key: []const u8, style: Subcontext) !void {
		try self.subcontext_hashmap.put(key, style);
	}

	pub fn getSubcontext(self: *const @This(), key: []const u8) ?*anyopaque {
		const style = self.subcontext_hashmap.get(key) orelse return null;
		return style.ptr;
	}
};
