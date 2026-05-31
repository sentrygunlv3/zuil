//! all the builtin widgets

const std = @import("std");

pub const zuil = @import("zuilcore");
pub const c = @import("c");

pub const svg = @import("helpers/svg.zig");
pub const font = @import("helpers/font.zig");

pub const NAME = "ZWidgets";

pub const ZWidgetContext = struct {
	freetype: c.FT_Library = undefined,

	fonts: std.StringHashMapUnmanaged(*font.ZFont),
	font_textures: std.AutoHashMap(*font.ZFont, zuil.context.TextureHandle),

	pub fn init(context: *zuil.ZContext) !*@This() {
		const self = try context.allocator.create(@This());
		errdefer context.allocator.destroy(self);

		self.* = .{
			.fonts = .empty,
			.font_textures = .init(context.allocator),
		};
		errdefer self.fonts.deinit();
		errdefer self.font_textures.deinit();

		_ = c.FT_Init_FreeType(&self.freetype);
		errdefer _ = c.FT_Done_FreeType(self.freetype);

		return self;
	}

	pub fn deinit(self: *@This(), context: *zuil.ZContext) void {
		var font_it = self.fonts.iterator();
		while (font_it.next()) |entry| {
			entry.value_ptr.*.deinit(context.allocator);
		}
		self.fonts.deinit(context.allocator);

		var ftex_it = self.font_textures.iterator();
		while (ftex_it.next()) |entry| {
			context.renderer.resourceRemoveUser(entry.value_ptr) catch |e| {
				context.log(.err, "failed to deinit font texture: {}", .{e});
			};
		}
		self.font_textures.deinit();

		_ = c.FT_Done_FreeType(self.freetype);

		context.allocator.destroy(self);
	}

	pub fn getFontTexture(self: *@This(), context: *zuil.ZContext, f: *font.ZFont) !zuil.context.TextureHandle {
		if (self.font_textures.get(f)) |s| {
			return s;
		}
		var handle = try context.createTexture(&f.texture);
		errdefer context.resourceRemoveUser(&handle) catch {};
		try self.font_textures.put(f, handle);
		return handle;
	}
};

fn deinitContext(s: *anyopaque, context: *zuil.ZContext) void {
	const self: *ZWidgetContext = @ptrCast(@alignCast(s));
	self.deinit(context);
}

pub fn register(context: *zuil.ZContext) anyerror!void {
	const subcontext = try ZWidgetContext.init(context);
	errdefer subcontext.deinit(context);

	try context.putSubcontext(NAME, .{
		.ptr = subcontext,
		.func_deinit = &deinitContext,
	});
}

pub fn registerShader(context: *zuil.ZContext) anyerror!void {
	@import("shaders/container.zig").register(context);
	@import("shaders/bitmap.zig").register(context);
	@import("shaders/font.zig").register(context);
}

fn buildFunc(T: type) fn (context: *zuil.context.ZContext) *T {
	return struct {
		fn func(context: *zuil.context.ZContext) *T {
			return T.init(context) catch |e| {
				@import("std").debug.panic("{}", .{e});
			};
		}
	}.func;
}

pub const zcontainer = @import("widgets/container.zig");
pub const container = buildFunc(zcontainer.ZContainerBuilder);
pub const zlist = @import("widgets/list.zig");
pub const list = buildFunc(zlist.ZListBuilder);
pub const zicon = @import("widgets/icon.zig");
pub const icon = buildFunc(zicon.ZIconBuilder);
pub const zposition = @import("widgets/position.zig");
pub const position = buildFunc(zposition.ZPositionBuilder);
pub const ztext = @import("widgets/text.zig");
pub const text = buildFunc(ztext.zTextBuilder);
pub const zbutton = @import("widgets/button.zig");
pub const button = buildFunc(zbutton.ZButtonBuilder);

pub const Style = struct {
	background: zuil.color.ZColor = .rgb256(41, 44, 48),
	container: struct {
		radius: f32 = 10,
		color: zuil.color.ZColor = .rgb256(40, 40, 41),
		border: zuil.color.ZColor = .rgb256(90, 90, 100),
	} = .{},
	text: struct {
		color: zuil.color.ZColor = .rgb(0.9, 0.9, 0.9),
	} = .{},

	pub fn deinit(self: *anyopaque, alloc: std.mem.Allocator) void {
		alloc.destroy(@as(*@This(), @ptrCast(@alignCast(self))));
	}
};

pub fn addStyles(alloc: std.mem.Allocator, theme: *zuil.Theme) !void {
	const t = try alloc.create(Style);
	errdefer alloc.destroy(t);

	t.* = .{};

	try theme.put(@typeName(Style), .{
		.ptr = t,
		.func_deinit = Style.deinit,
	});
	theme.background = .BLACK;
	theme.background.a = 0.5;
}
