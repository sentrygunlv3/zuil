const std = @import("std");
const root = @import("root.zig");

const gl = root.gl;
const input = root.input;
const widget = root.widget;
const types = root.types;

pub const ZWidgetTree = struct {
	arena: std.heap.ArenaAllocator = undefined,
	context: *root.ZContext = undefined,
	current_bounds: types.ZBounds = .zero,
	flags: packed struct {
		layout_dirty: bool = true,
		render_dirty: bool = true,
		render_dirty_full: bool = true,
		_: u5 = 0,
	} = .{},
	dirty: ?types.ZBounds = .zero,
	// --- input
	key_events: std.ArrayList(input.ZEvent) = undefined,
	focused_widget: ?*widget.ZWidget = null,
	// ---
	root: ?*widget.ZWidget = undefined,
	content_alignment: types.ZAlign = .default,
	display_size: struct {x: f32 = 0, y: f32 = 0} = .{},

	pub fn init(physical_w: f32, physical_h: f32, root_widget: ?*widget.ZWidget, context: *root.ZContext) !*@This() {
		const self = try context.allocator.create(@This());
		errdefer self.deinit();

		self.* = .{
			.key_events = try std.ArrayList(input.ZEvent).initCapacity(context.allocator, 0),
			.root = root_widget,
			.context = context,
			.arena = std.heap.ArenaAllocator.init(context.allocator),
			.display_size = .{.x = physical_w, .y = physical_h},
		};
		errdefer self.key_events.deinit(context.allocator);
		errdefer self.arena.deinit();

		if (self.root) |r| {
			r.setWindow(self);
		}

		return self;
	}

	pub fn deinit(self: *@This()) void {
		if (self.root) |r| {
			r.destroy() catch {
				self.context.log(.err, "{*} trees root has a bad state", .{self});
			};
		}

		self.key_events.deinit(self.context.allocator);
		self.arena.deinit();
		self.context.allocator.destroy(self);
	}

	pub fn setRoot(self: *@This(), root_widget: ?*widget.ZWidget) void {
		if (self.root) |r| {
			r.destroy() catch {
				self.context.log(.err, "{*} trees root has a bad state", .{self});
			};
		}
		self.root = root_widget;
	}

	pub fn markDirty(self: *@This()) void {
		self.flags.layout_dirty = true;
	}

	pub fn markDirtyRender(self: *@This(), area: types.ZBounds) void {
		self.flags.render_dirty = true;

		if (self.dirty != null) {
			self.dirty.?.x = @min(self.dirty.?.x, area.x);
			self.dirty.?.y = @min(self.dirty.?.y, area.y);
			self.dirty.?.w = @max(self.dirty.?.w, area.w);
			self.dirty.?.h = @max(self.dirty.?.h, area.h);
		} else {
			self.dirty = area;
		}
	}

	pub fn setContentAlignment(self: *@This(), new: types.ZAlign) void {
		self.content_alignment = new;
		self.root.markDirty();
		self.markDirty();
	}

	pub fn getBounds(self: *@This()) types.ZBounds {
		return self.current_bounds;
	}

	pub fn layout(self: *@This()) anyerror!void {
		const space = self.getBounds();

		if (self.root) |r| {
			self.context.log(.debug, "updatePreferredSize", .{});
			r.updatePreferredSize(if (r.flags.layout_dirty) true else false, space.w, space.h) catch |e| {
				self.context.log(.warning, "a{}", .{e});
			};
			self.context.log(.debug, "updateActualSize", .{});
			r.updateActualSize(if (r.flags.layout_dirty) true else false, space.w, space.h) catch |e| {
				self.context.log(.warning, "b{}", .{e});
			};
			self.context.log(.debug, "updatePosition", .{});
			r.updatePosition(if (r.flags.layout_dirty) true else false, space.w, space.h) catch |e| {
				self.context.log(.warning, "c{}", .{e});
			};
		}

		self.flags.layout_dirty = false;
	}

	pub fn render(self: *@This()) anyerror!void {
		defer _ = self.arena.reset(.free_all);
		if (self.root) |r| {
			var commands = try root.context.RenderCommandList.init(self.arena.allocator());

			var area = if (self.flags.render_dirty_full) null else self.dirty;

			try r.render(
				self,
				&commands,
				area
			);
			self.context.log(.debug, "area: {} flags: {}", .{if (self.dirty != null) self.dirty.? else types.ZBounds.zero, self.flags});
			self.context.log(.debug, "total commands: {}", .{commands.commands.items.len});

			if (area != null) {
				// to opengl coordinates
				area.?.y = self.getBounds().h - area.?.h - area.?.y;
			}
			self.context.clip(area);
			self.context.clear(root.color.GREY);
			try self.context.renderCommands(&commands);
		}
		self.context.clip(null);

		self.flags.render_dirty = false;
		self.flags.render_dirty_full = false;
		self.dirty = null;

		self.context.resourcesUpdate();
	}
};
