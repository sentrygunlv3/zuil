//! all the builtin widgets

const std = @import("std");

pub const zuil = @import("zuilcore");
pub const c = @import("c");

pub const svg = @import("helpers/svg.zig");
pub const font = @import("helpers/font.zig");

pub const NAME = "ZWidgets";

pub const ZWidgetContext = struct {
	context: *zuil.ZContext,
	freetype: c.FT_Library = undefined,

	fonts: std.StringHashMapUnmanaged(*font.ZFont),
	font_textures: std.AutoHashMap(*anyopaque, *PainterData),

	pub const PainterData = struct {
		font_textures: std.AutoHashMap(*font.ZFont, zuil.context.TextureHandle),
	};

	pub fn init(context: *zuil.ZContext) !*@This() {
		const self = try context.allocator.create(@This());
		errdefer context.allocator.destroy(self);

		self.* = .{
			.context = context,
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

		var fontt_it = self.font_textures.iterator();
		while (fontt_it.next()) |entry| {
			entry.value_ptr.*.font_textures.deinit();
			context.allocator.destroy(entry.value_ptr.*);
		}
		self.font_textures.deinit();

		_ = c.FT_Done_FreeType(self.freetype);

		context.allocator.destroy(self);
	}

	pub fn getFontTexture(self: *@This(), painter: *zuil.context.ZPainter, f: *font.ZFont) !zuil.context.TextureHandle {
		if (self.font_textures.get(painter)) |s| {
			if (s.font_textures.get(f)) |t| {
				return t;
			} else {
				const handle = try painter.createTexture(&f.texture);
				errdefer painter.resourceRemoveUser(handle) catch {};
				try s.font_textures.put(f, handle);
				return handle;
			}
		} else {
			const handle = try painter.createTexture(&f.texture);
			errdefer painter.resourceRemoveUser(handle) catch {};

			var d = self.font_textures.get(painter.ptr);
			if (d == null) {
				d = try self.context.allocator.create(PainterData);
				errdefer self.context.allocator.destroy(d.?);
				d.?.font_textures = .init(self.context.allocator);
				errdefer d.?.font_textures.deinit();
				try self.font_textures.put(painter.ptr, d.?);
			}
			errdefer self.context.allocator.destroy(d.?);
			errdefer d.?.font_textures.deinit();

			try d.?.font_textures.put(f, handle);
			return handle;
		}
		return error.noFont;
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

pub const ContainerColor = union(enum) {
	none: void,
	custom: zuil.color.ZColor,

	surface: void,
	surface_border: void,
	button: void,
	button_border: void,
	background: void,

	pub fn get(self: *@This(), style: *Style, focused: bool) zuil.color.ZColor {
		return switch (self.*) {
			.none => .TRANSPARENT,
			.surface => style.surface.color,
			.surface_border => style.surface.border,
			.button => if (!focused) style.surface.button.color else style.surface.button.color_hovered,
			.button_border => if (!focused) style.surface.button.border else style.surface.button.border_hovered,
			.background => if (focused) style.background else style.background_unfocused,
			.custom => |selected| selected,
		};
	}
};

pub const Style = struct {
	background: zuil.color.ZColor = .rgb256(41, 44, 48),
	background_unfocused: zuil.color.ZColor = .rgb256(32, 35, 38),
	surface: struct {
		radius: f32 = 10,
		color: zuil.color.ZColor = .rgb256(90, 90, 100),
		border: zuil.color.ZColor = .rgb256(100, 110, 115),
		button: struct {
			color: zuil.color.ZColor = .TRANSPARENT,
			color_hovered: zuil.color.ZColor = .rgba256(41, 158, 249, 70),
			border: zuil.color.ZColor = .ZBLUE,
			border_hovered: zuil.color.ZColor = .ZBLUE,
		} = .{},
	} = .{},
	decoration: struct {
		on_surface: zuil.color.ZColor = .WHITE,
		on_color: zuil.color.ZColor = .BLACK,
		danger: zuil.color.ZColor = .RED,
		success: zuil.color.ZColor = .GREEN,
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
