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

			builder.widget.super.setSize(.{
				.w = w,
				.h = h
			});
			return builder;
		}

		pub fn margin(self: *@This(), new: root.types.ZMargin) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.super.margin = new;
			builder.widget.super.markDirty();
			return builder;
		}

		pub fn keepSizeRatio(self: *@This(), state: bool) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.super.setKeepRatio(state);
			return builder;
		}
	};
}
