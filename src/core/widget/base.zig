const std = @import("std");
const root = @import("../root.zig");

const ZError = root.ZError;

const types = root.types;
const ZBounds = root.types.ZBounds;
const ZPosition = root.types.ZPosition;
const ZSize = root.types.ZSize;
const ZMargin = root.types.ZMargin;
const ZAlign = root.types.ZAlign;

pub const BuilderMixin = @import("builder.zig").BuilderMixin;

/// base widget struct
/// 
/// this type is used for creating a new widget type by adding this to the new widgets struct:
/// ```
/// super: ZWidget = .{.fi = &vtable},
///
/// pub const vtable = ZWidget.VTable.generate(@This());
///
/// ```
/// 
/// you can see all the functions a widget can have in `ZWidget.VTable`
pub const ZWidget = struct {
	fi: *const VTable,
	flags: packed struct {
		layout_dirty: bool = true,
		keep_size_ratio: bool = false,
		ignore_input: bool = false,
		_: u5 = 0,
	} = .{},
	// tree
	parent: ?*ZWidget = null,
	window: ?*root.tree.ZWidgetTree = null,
	// calculated
	clamped_bounds: ZBounds = .zero,
	size_ratio: f32 = 0,
	// layout
	size: ZSize = .zero,
	size_min: ZSize = .zero,
	size_max: ZSize = .fill,
	margin: ZMargin = .zero,

	pub const VTable = @import("interface.zig").ZWidgetFI;

	/// call destroy when removing widget from tree
	pub fn deinit(self: *@This(), context: *root.context.ZContext) void {
		self.fi.deinit(self, context);
	}

	pub fn enterTree(self: *@This()) void {
		if (self.fi.enterTree) |func| {
			func(self);
		}
	}

	/// removes references from everything in the tree except the parent widget
	pub fn exitTreeExceptParent(self: *@This()) !void {
		if (self.window == null) return error.NotInTree;

		if (self.fi.exitTree) |func| {
			func(self);
		}

		if (self.window.?.focused_widget == self) {
			self.window.?.focused_widget = null;
		}
		if (self.window.?.last_hover == self) {
			self.window.?.focused_widget = null;
		}
		self.window = null;
	}

	pub fn exitTree(self: *@This()) !void {
		try self.exitTreeExceptParent();
		if (self.parent != null) {
			self.parent.?.removeChild(self) catch |e| {
				self.window.?.context.log(.err, "exit tree: {}", .{e});
			};
			self.parent = null;
		}
	}

	pub fn destroy(self: *@This()) !void {
		if (self.window) |tree| {
			try self.exitTree();
			self.deinit(tree.context);
			return;
		}
		return error.NotInTree;
	}

	pub fn markDirty(self: *@This()) void {
		self.flags.layout_dirty = true;
		if (self.window) |window| {
			window.markDirty();
			window.markDirtyRender(self.clamped_bounds);
		}
	}

	pub fn markDirtyRender(self: *@This()) void {
		if (self.window) |window| {
			window.markDirtyRender(self.clamped_bounds);
		}
	}

	// ---

	pub fn setSize(self: *@This(), new: ZSize) void {
		self.size = new;
		self.markDirty();
	}

	pub fn setKeepRatio(self: *@This(), new: bool) void {
		self.flags.keep_size_ratio = new;
		self.markDirty();
	}

	pub fn setIgnoreInput(self: *@This(), new: bool) void {
		self.flags.ignore_input = new;
		self.markDirty();
	}

	pub fn getName(self: *@This()) []const u8 {
		return self.fi.name;
	}

	pub fn as(self: *@This(), comptime T: type) *T {
		return @as(*T, @alignCast(@fieldParentPtr("super", self)));
	}

	pub fn is(self: *@This(), comptime T: type) bool {
		if (self.fi == &T.vtable) return true;
		return false;
	}

	pub fn cast(self: *@This(), comptime T: type) ?*T {
		if (self.fi != &T.vtable) return null;
		return @as(*T, @alignCast(@fieldParentPtr("super", self)));
	}

	// ---

	pub fn setWindow(self: *@This(), window: ?*root.tree.ZWidgetTree) void {
		if (self.window == null and window == null) return;
		self.window = window;

		if (window != null) {
			self.enterTree();
		}

		const children = self.getChildren() orelse return;
		for (children) |child| {
			child.setWindow(window);
		}
	}

	pub fn render(self: *@This(), tree: *root.tree.ZWidgetTree, area: ?types.ZBounds) anyerror!void {
		tree.context.log(.debug, "{*} - {s}", .{self, self.getName()});
		tree.context.log(.debug, "bounds: {}", .{self.clamped_bounds});

		if (self.fi.render) |func| {
			try func(self, tree, if (area != null) area.? else null);
		}
	}

	pub fn updatePreferredSize(self: *@This(), dirty: bool, x: f32, y: f32) anyerror!void {
		if (self.fi.updatePreferredSize) |func| {
			try func(self, dirty, x, y);
		}
	}

	pub fn updateActualSize(self: *@This(), dirty: bool, x: f32, y: f32) anyerror!void {
		if (self.fi.updateActualSize) |func| {
			try func(self, dirty, x, y);
		}
	}

	pub fn updatePosition(self: *@This(), dirty: bool, w: f32, h: f32) anyerror!void {
		if (self.fi.updatePosition) |func| {
			try func(self, dirty, w, h);
		}
		self.flags.layout_dirty = false;
		self.window.?.markDirtyRender(self.clamped_bounds);
	}

	pub fn isOverPoint(self: *@This(), x: f32, y: f32, parent_outside: bool) ?*@This() {
		if (self.fi.isOverPoint) |func| {
			return func(self, x, y, parent_outside);
		}
		return null;
	}

	pub fn event(self: *@This(), e: root.input.ZEvent) anyerror!void {
		if (self.fi.event) |func| {
			func(self, e);
		}
	}

	pub fn getChildren(self: *@This()) ?[]*ZWidget {
		if (self.fi.getChildren) |func| {
			return func(self);
		}
		return null;
	}

	/// this only removes the child from the parent
	/// 
	/// to remove the child from the whole tree call `exitTree` on the child
	/// 
	/// to destroy the child call `destroy` on the child
	pub fn removeChild(self: *@This(), child: *@This()) anyerror!void {
		if (self.fi.removeChild) |func| {
			try func(self, child);
		}
		return ZError.MissingWidgetFunction;
	}
};
