const std = @import("std");
const root = @import("../root.zig");

/// common builder functions
/// 
/// add to widget builder with:
/// `c: BuilderMixin(@This()) = .{},`
/// 
/// mixin idea originally from:
/// https://github.com/ziglang/zig/issues/20663
pub fn BuilderMixin(comptime T: type) type {
	return struct {
		pub fn size(self: *@This(), w: root.types.ZUnit, h: root.types.ZUnit) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.setSize(.{
				.w = w,
				.h = h
			});
			return builder;
		}

		pub fn margin(self: *@This(), new: root.types.ZMargin) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.margin = new;
			builder.widget.markDirty();
			return builder;
		}

		pub fn keepSizeRatio(self: *@This(), state: bool) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.setKeepRatio(state);
			return builder;
		}

		pub fn eventCallback(self: *@This(), event: *const fn (self: *root.zwidget.ZWidget, event: root.input.ZEvent) anyerror!void) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.mutable_fi.event = event;
			return builder;
		}
	};
}
