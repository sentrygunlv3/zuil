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

		pub fn position(self: *@This(), x: root.types.ZUnit, y: root.types.ZUnit) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.setPosition(.{
				.x = x,
				.y = y,
			});
			return builder;
		}

		pub fn margin(self: *@This(), top: root.types.ZUnit, bottom: root.types.ZUnit, left: root.types.ZUnit, right: root.types.ZUnit) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.setMargin(.{
				.top = top,
				.bottom = bottom,
				.left = left,
				.right = right
			});
			return builder;
		}

		pub fn content_align(self: *@This(), a: root.types.ZAlign) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.setContentAlignment(a);
			return builder;
		}

		pub fn layout(self: *@This(), l: root.types.ZLayout) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.setLayout(l);
			return builder;
		}

		pub fn eventCallback(self: *@This(), event: *const fn (self: *root.zwidget.ZWidget, event: root.input.ZEvent) anyerror!void) *T {
			const builder: *T = @alignCast(@fieldParentPtr("c", self));

			builder.widget.mutable_fi.event = event;
			return builder;
		}
	};
}
