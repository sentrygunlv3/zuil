const std = @import("std");
const root = @import("root.zig");
const zrenderer = @import("renderer.zig");

pub const RenderCommand = zrenderer.RenderCommand;
pub const TextureParameter = zrenderer.TextureParameter;
pub const ShaderParameter = zrenderer.ShaderParameter;
pub const ZPainter = zrenderer.ZPainter;

pub const MeshHandle = ResourceHandle;
pub const TextureHandle = ResourceHandle;

pub const ResourceHandle = struct {
	resource: *anyopaque,
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
	io: std.Io,

	external: struct {
		log: *const fn (t: LogType, string: []const u8) void = log_default,
	},

	theme: *root.Theme,

	subcontext_hashmap: std.StringHashMap(Subcontext),

	pub const Subcontext = struct {
		ptr: *anyopaque,
		func_deinit: *const fn (self: *anyopaque, context: *ZContext) void,
	};

	pub fn init(allocator: std.mem.Allocator, io: std.Io, theme: *root.Theme) !*@This() {
		const self = try allocator.create(@This());
		errdefer self.allocator.destroy(self);

		self.* = .{
			.allocator = allocator,
			.io = io,
			.external = .{},
			.theme = theme,
			.subcontext_hashmap = .init(allocator),
		};
		errdefer self.subcontext_hashmap.deinit();

		return self;
	}

	pub fn deinit(self: *@This()) void {
		var it = self.subcontext_hashmap.valueIterator();
		while (it.next()) |s| {
			s.func_deinit(s.ptr, self);
		}

		self.subcontext_hashmap.deinit();

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

	pub fn putSubcontext(self: *@This(), key: []const u8, style: Subcontext) !void {
		try self.subcontext_hashmap.put(key, style);
	}

	pub fn getSubcontext(self: *const @This(), key: []const u8) ?*anyopaque {
		const style = self.subcontext_hashmap.get(key) orelse return null;
		return style.ptr;
	}
};
