const std = @import("std");
const root = @import("../root.zig");

pub const ZWidgetFI = @import("interface.zig").ZWidgetFI;
pub const ZWidgetMutableFI = @import("interface.zig").ZWidgetMutableFI;

const errors = root.errors;

const types = root.types;
const ZBounds = root.types.ZBounds;
const ZPosition = root.types.ZPosition;
const ZSize = root.types.ZSize;
const ZMargin = root.types.ZMargin;
const ZAlign = root.types.ZAlign;

/// base widget struct
/// 
/// when creating a widget setting `fi` is used to choose the type\
/// `mutable_fi` is for functions that can be changed after creation and are not directly linked to the type
/// 
/// `type_name` has to have the name of the struct stored in `data`
pub const ZWidget = struct {
	type_name: []const u8 = "ZWidget",
	mutable_fi: ZWidgetMutableFI = .{},
	fi: *const ZWidgetFI,
	flags: packed struct {
		layout_dirty: bool = true,
		keep_size_ratio: bool = false,
		_: u6 = 0,
	} = .{},
	data: ?*anyopaque = null,
	// tree
	parent: ?*ZWidget = null,
	window: ?*root.tree.ZWidgetTree = null,
	// calculated
	clamped_bounds: ZBounds = .zero(),
	size_ratio: f32 = 0,
	// layout
	size: ZSize = .zero(),
	size_min: ZSize = .zero(),
	size_max: ZSize = .fill(),
	margin: ZMargin = .zero(),

	pub fn init(fi: *const ZWidgetFI) anyerror!*@This() {
		const self = try root.allocator.create(@This());
		self.* = @This(){
			.fi = fi,
		};
		if (self.fi.init) |func| {
			const r = errors.errorFromC(func(self));
			if (r) |ret| {
				if (self.fi.deinit) |funcd| {
					funcd(self);
				}
				return ret;
			}
		}
		return self;
	}

	/// call destroy when removing widget from window/tree
	pub fn deinit(self: *@This()) void {
		if (self.fi.deinit) |func| {
			func(self);
		}
		root.allocator.destroy(self);
	}

	pub fn enterTree(self: *@This()) void {
		if (self.fi.enterTree) |func| {
			func(self);
		}
	}

	/// removes references from everything in the tree except the parent widget
	pub fn exitTreeExceptParent(self: *@This()) void {
		if (self.fi.exitTree) |func| {
			func(self);
		}
		if (self.window) |window| {
			if (window.focused_widget == self) {
				window.focused_widget = null;
			}
			self.setWindow(null);
		}
	}

	pub fn exitTree(self: *@This()) void {
		self.exitTreeExceptParent();
		if (self.parent != null) {
			self.parent.?.removeChild(self) catch |e| {
				std.debug.print("exit tree: {}\n", .{e});
			};
			self.parent = null;
		}
	}

	pub fn destroy(self: *@This()) void {
		self.exitTree();
		self.deinit();
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

	pub fn getData(self: *@This(), T: type) ?*T {
		if (self.data) |d| {
			if (std.mem.eql(u8, self.type_name, @typeName(T))) {
				return @ptrCast(@alignCast(d));
			}
		}
		return null;
	}

	// ---

	pub fn setWindow(self: *@This(), window: ?*root.tree.ZWidgetTree) void {
		self.window = window;
		if (window != null) {
			self.enterTree();
		}
		const children = self.getChildren() catch {
			return;
		};
		for (children) |child| {
			child.setWindow(window);
		}
	}

	pub fn render(self: *@This(), window: *root.tree.ZWidgetTree, commands: *root.renderer.context.RenderCommandList, area: ?types.ZBounds) anyerror!void {
		if (@import("build_options").debug) {
			std.debug.print("\n{*} - {s}\n", .{self, self.type_name});
			std.debug.print("bounds: {}\n", .{self.clamped_bounds});
		}
		if (self.fi.render) |func| {
			const r = errors.errorFromC(func(self, window, commands, if (area != null) &area.? else null));
			if (r) |ret| {
				return ret;
			}
		}
	}

	pub fn updatePreferredSize(self: *@This(), dirty: bool, x: f32, y: f32) anyerror!void {
		if (self.fi.updatePreferredSize) |func| {
			const r = errors.errorFromC(func(self, dirty, x, y));
			if (r) |ret| {
				return ret;
			}
		}
	}

	pub fn updateActualSize(self: *@This(), dirty: bool, x: f32, y: f32) anyerror!void {
		if (self.fi.updateActualSize) |func| {
			const r = errors.errorFromC(func(self, dirty, x, y));
			if (r) |ret| {
				return ret;
			}
		}
	}

	pub fn updatePosition(self: *@This(), dirty: bool, w: f32, h: f32) anyerror!void {
		if (self.fi.updatePosition) |func| {
			const r = errors.errorFromC(func(self, dirty, w, h));
			if (r) |ret| {
				return ret;
			}
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
		if (self.mutable_fi.event) |func| {
			const r = errors.errorFromC(func(self, &e));
			if (r) |ret| {
				return ret;
			}
		}
	}

	pub fn getChildren(self: *@This()) anyerror![]*ZWidget {
		if (self.fi.getChildren) |func| {
			var size: usize = 0;
			const ptr = func(self, &size);
			return ptr[0..size];
		}
		return errors.ZError.MissingWidgetFunction;
	}

	/// this only removes the child from the parent
	/// 
	/// to remove the child from the whole tree call `exitTree` on the child
	/// 
	/// to destroy the child call `destroy` on the child
	pub fn removeChild(self: *@This(), child: *@This()) anyerror!void {
		if (self.fi.removeChild) |func| {
			const r = errors.errorFromC(func(self, child));
			if (r) |ret| {
				return ret;
			}
		}
		return errors.ZError.MissingWidgetFunction;
	}
};
