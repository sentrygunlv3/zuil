//! all the builtin widgets

const std = @import("std");

pub const zuil = @import("zuilcore");

/// registers all builtin shaders
pub fn registerAllFunc(context: *zuil.ZContext) anyerror!void {
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

pub const Style = struct {
	//background: zuil.color.ZColor = .default,
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
	theme.background = .rgb256(41, 44, 48);
}
