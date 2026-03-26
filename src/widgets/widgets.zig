//! all the builtin widgets

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
