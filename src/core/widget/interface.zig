const std = @import("std");
const root = @import("../root.zig");

const errors = root.errors;

const types = root.types;
const ZBounds = root.types.ZBounds;
const ZPosition = root.types.ZPosition;
const ZSize = root.types.ZSize;
const ZMargin = root.types.ZMargin;
const ZAlign = root.types.ZAlign;
const ZWidget = root.widget.ZWidget;

pub fn generateFI(comptime t: type) ZWidgetFI {
	const hasInit = @hasDecl(t, "init");
	const hasDeinit = @hasDecl(t, "deinit");
	const hasEnterTree = @hasDecl(t, "enterTree");
	const hasExitTree = @hasDecl(t, "exitTree");

	if (hasInit and !hasDeinit or !hasInit and hasDeinit) {
		@compileError("widget cant have only init or deinit, has to have both or neither");
	}

	if (hasEnterTree and !hasExitTree or !hasEnterTree and hasExitTree) {
		@compileError("widget cant have only enterTree or exitTree, has to have both or neither");
	}

	return .{
		.init = if (hasInit) t.init else null,
		.deinit = if (hasDeinit) t.deinit else null,
		.enterTree = if (hasEnterTree) t.enterTree else null,
		.exitTree = if (hasExitTree) t.exitTree else null,
		.updatePreferredSize = if (@hasDecl(t, "updatePreferredSize")) t.updatePreferredSize else updatePreferredSize,
		.updateActualSize = if (@hasDecl(t, "updateActualSize")) t.updateActualSize else updateActualSize,
		.updatePosition = if (@hasDecl(t, "updatePosition")) t.updatePosition else updatePosition,
		.render = if (@hasDecl(t, "render")) t.render else render,
		.isOverPoint = if (@hasDecl(t, "isOverPoint")) t.isOverPoint else isOverPoint,
		.getChildren = if (@hasDecl(t, "getChildren")) t.getChildren else null,
		.removeChild = if (@hasDecl(t, "removeChild")) t.removeChild else null,
	};
}

/// widget function interface for widget classes
pub const ZWidgetFI = struct {
	init: ?*const fn (self: *ZWidget, context: *root.context.ZContext) callconv(.c) c_int = null,
	deinit: ?*const fn (self: *ZWidget, context: *root.context.ZContext) callconv(.c) void = null,

	enterTree: ?*const fn (self: *ZWidget) callconv(.c) void = null,
	exitTree: ?*const fn (self: *ZWidget) callconv(.c) void = null,

	/// bottom to top
	updatePreferredSize: ?*const fn (self: *ZWidget, dirty: bool, w: f32, h: f32) callconv(.c) c_int = updatePreferredSize,
	/// top to bottom
	updateActualSize: ?*const fn (self: *ZWidget, dirty: bool, w: f32, h: f32) callconv(.c) c_int = updateActualSize,
	/// top to bottom
	updatePosition: ?*const fn (self: *ZWidget, dirty: bool, w: f32, h: f32) callconv(.c) c_int = updatePosition,

	render: ?*const fn (self: *ZWidget, window: *root.tree.ZWidgetTree, commands: *root.context.RenderCommandList, area: ?*const types.ZBounds) callconv(.c) c_int = render,

	isOverPoint: ?*const fn (self: *ZWidget, x: f32, y: f32, parent_outside: bool) callconv(.c) ?*ZWidget = isOverPoint,

	getChildren: ?*const fn (self: *ZWidget, return_len: *usize) callconv(.c) [*]*ZWidget = null,
	removeChild: ?*const fn (self: *ZWidget, child: *ZWidget) callconv(.c) c_int = null,
};

/// widget function interface for per widget functions
pub const ZWidgetMutableFI = struct {
	event: ?*const fn (self: *ZWidget, event: *const root.input.ZEvent) callconv(.c) c_int = null,
};

pub fn render(self: *ZWidget, window: *root.tree.ZWidgetTree, commands: *root.context.RenderCommandList, area: ?*const types.ZBounds) callconv(.c) c_int {
	const children = self.getChildren() catch {
		return 0;
	};
	for (children) |child| {
		child.render(window, commands, if (area != null) area.?.* else null) catch return @intFromEnum(errors.ZErrorC.renderWidgetFailed);
	}
	return 0;
}

pub fn isOverPoint(self: *ZWidget, x: f32, y: f32, parent_outside: bool) callconv(.c) ?*ZWidget {
	var ref: ?*ZWidget = null;
	var outside = true;

	if (!parent_outside) {
		if (
			self.clamped_bounds.x < x and
			self.clamped_bounds.x + self.clamped_bounds.w > x and
			self.clamped_bounds.y < y and
			self.clamped_bounds.y + self.clamped_bounds.h > y
		) {
			ref = self;
			outside = false;
		}
	}

	const children = self.getChildren() catch |e| {
		std.debug.print("{}\n", .{e});
		return null;
	};

	for (children) |child| {
		if (child.isOverPoint(x, y, outside)) |new| {
			ref = new;
		}
	}
	return ref;
}

pub fn updatePreferredSize(self: *ZWidget, dirty: bool, w: f32, h: f32) callconv(.c) c_int {
	if (dirty) {
		const size_w = if (self.size.w == .percentage) 0 else self.size.w.asPixel(false, .{.w = w, .h = h}, self.window.?);
		const size_h = if (self.size.h == .percentage) 0 else self.size.h.asPixel(true, .{.w = w, .h = h}, self.window.?);

		self.clamped_bounds = .{
			.w = size_w,
			.h = size_h,
		};

		self.size_ratio = size_w / size_h;
	} else {
		const children = self.getChildren() catch {
			return 0;
		};
		for (children) |child| {
			child.updatePreferredSize(
				dirty or child.flags.layout_dirty,
				w,
				h
			) catch return @intFromEnum(errors.ZErrorC.updatePreferredSizeFailed);
		}
		return 0;
	}

	const children = self.getChildren() catch {
		return 0;
	};

	const size_max_w = if (self.size_max.w == .percentage) 0 else self.size_max.w.asPixel(false, .{.w = w, .h = h}, self.window.?);
	const size_max_h = if (self.size_max.h == .percentage) 0 else self.size_max.h.asPixel(true, .{.w = w, .h = h}, self.window.?);

	for (children) |child| {
		child.updatePreferredSize(
			dirty or child.flags.layout_dirty,
			w,
			h
		) catch return @intFromEnum(errors.ZErrorC.updatePreferredSizeFailed);
		if (self.clamped_bounds.w < child.clamped_bounds.w) {
			if (child.clamped_bounds.w > size_max_w) {
				self.clamped_bounds.w = size_max_w;
			} else {
				self.clamped_bounds.w = child.clamped_bounds.w;
			}
		}

		if (self.clamped_bounds.h < child.clamped_bounds.h) {
			if (child.clamped_bounds.h > size_max_h) {
				self.clamped_bounds.h = size_max_h;
			} else {
				self.clamped_bounds.h = child.clamped_bounds.h;
			}
		}
	}
	return 0;
}

pub fn updateActualSize(self: *ZWidget, dirty: bool, w: f32, h: f32) callconv(.c) c_int {
	const margin = self.margin.asPixel(.{.w = w, .h = h}, self.window.?);
	const width = w - (margin.left + margin.right);
	const height = h - (margin.top + margin.bottom);
	if (dirty) {
		const size_max_w = self.size_max.w.asPixel(false, .{.w = width, .h = height}, self.window.?);
		const size_max_h = self.size_max.h.asPixel(true, .{.w = width, .h = height}, self.window.?);

		if (self.size.w == .percentage) {
			self.clamped_bounds.w = self.size.w.asPixel(false, .{.w = width, .h = height}, self.window.?);
		}
		if (self.size.h == .percentage) {
			self.clamped_bounds.h = self.size.h.asPixel(true, .{.w = width, .h = height}, self.window.?);
		}

		if (self.clamped_bounds.w > size_max_w) {
			self.clamped_bounds.w = size_max_w;
		}
		if (self.clamped_bounds.h > size_max_h) {
			self.clamped_bounds.h = size_max_h;
		}

		if (self.flags.keep_size_ratio) {
			if (width < height) {
				self.clamped_bounds.h = self.clamped_bounds.w / self.size_ratio;
			} else {
				self.clamped_bounds.w = self.clamped_bounds.h * self.size_ratio;
			}
		}
	}

	const children = self.getChildren() catch {
		return 0;
	};

	for (children) |child| {
		child.updateActualSize(
			dirty or child.flags.layout_dirty,
			self.clamped_bounds.w,
			self.clamped_bounds.h
		) catch return @intFromEnum(errors.ZErrorC.updateActualSizeFailed);
	}
	return 0;
}

/// dirty forces all widgets from this point on to recalculate their layouts
pub fn updatePosition(self: *ZWidget, dirty: bool, w: f32, h: f32) callconv(.c) c_int {
	const margin = self.margin.asPixel(.{.w = w, .h = h}, self.window.?);
	self.clamped_bounds.x += margin.left;
	self.clamped_bounds.y += margin.top;

	const children = self.getChildren() catch {
		return 0;
	};

	for (children) |child| {
		child.clamped_bounds.x = self.clamped_bounds.x;
		child.clamped_bounds.y = self.clamped_bounds.y;
		child.updatePosition(dirty or child.flags.layout_dirty, self.clamped_bounds.w, self.clamped_bounds.h) catch return @intFromEnum(errors.ZErrorC.updatePositionFailed);
	}
	return 0;
}
