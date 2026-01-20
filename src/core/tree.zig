const std = @import("std");
const root = @import("root.zig");

const gl = root.gl;
const input = root.input;
const zwidget = root.zwidget;
const types = root.types;

pub const ZWidgetTree = struct {
	arena: std.heap.ArenaAllocator = undefined,
	context: *root.renderer.context.RenderContext = undefined,
	current_bounds: types.ZBounds = .zero(),
	flags: packed struct {
		layout_dirty: bool = true,
		render_dirty: bool = true,
		render_dirty_full: bool = true,
		shared_context: bool = false,
		_: u4 = 0,
	} = .{},
	dirty: ?types.ZBounds = .zero(),
	// --- input
	key_events: std.ArrayList(input.ZEvent) = undefined,
	focused_widget: ?*zwidget.ZWidget = null,
	// ---
	root: ?*zwidget.ZWidget = undefined,
	content_alignment: types.ZAlign = .default(),
	display_size: struct {x: f32 = 0, y: f32 = 0} = .{},

	pub fn init(physical_w: f32, physical_h: f32, root_widget: ?*zwidget.ZWidget, context: ?*root.renderer.context.RenderContext) !*@This() {
		const self = try root.allocator.create(@This());
		errdefer self.deinit();

		self.* = .{
			.key_events = try std.ArrayList(input.ZEvent).initCapacity(root.allocator, 0),
			.root = root_widget,
		};

		if (context) |c| {
			self.context = c;
			self.flags.shared_context = true;
		} else {
			self.context = try root.renderer.context.RenderContext.init();
			if (root.onContextCreate) |func| {
				try func(self.context);
			}
		}

		root.gl.enable(root.gl.BLEND);
		root.gl.blendFunc(root.gl.SRC_ALPHA, root.gl.ONE_MINUS_SRC_ALPHA);
		
		self.arena = std.heap.ArenaAllocator.init(root.allocator);

		self.display_size = .{.x = physical_w, .y = physical_h};

		if (self.root) |r| {
			r.setWindow(self);
		}

		return self;
	}

	pub fn deinit(self: *@This()) void {
		if (self.root) |r| {
			r.destroy();
		}
		if (!self.flags.shared_context) {
			self.context.deinit();
		}
		self.key_events.deinit(root.allocator);
		self.arena.deinit();
		root.allocator.destroy(self);
	}

	pub fn setRoot(self: *@This(), root_widget: ?*zwidget.ZWidget) void {
		if (self.root) |r| {
			r.destroy();
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

	fn resize(self: *@This(), w: i32, h: i32) void {
		if (self.root) |r| {
			r.markDirty();
		}
		self.flags.render_dirty_full = true;

		gl.bindTexture(gl.TEXTURE_2D, self.render_texture);
		gl.texImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGBA,
			w,
			h,
			0,
			gl.RGBA,
			gl.UNSIGNED_BYTE,
			null
		);
		gl.bindTexture(gl.TEXTURE_2D, 0);
	}

	pub fn getBounds(self: *@This()) types.ZBounds {
		return self.current_bounds;
	}

	pub fn layout(self: *@This()) anyerror!void {
		const space = self.getBounds();

		if (self.root) |r| {
			if (@import("build_options").debug) std.debug.print("updatePreferredSize\n", .{});
			try r.updatePreferredSize(if (r.flags.layout_dirty) true else false, space.w, space.h);
			if (@import("build_options").debug) std.debug.print("updateActualSize\n", .{});
			try r.updateActualSize(if (r.flags.layout_dirty) true else false, space.w, space.h);
			if (@import("build_options").debug) std.debug.print("updatePosition\n", .{});
			try r.updatePosition(if (r.flags.layout_dirty) true else false, space.w, space.h);
		}

		self.flags.layout_dirty = false;
	}

	pub fn render(self: *@This()) anyerror!void {
		if (self.root) |r| {
			var commands = try root.renderer.context.RenderCommandList.init(self.arena.allocator());

			var area = if (self.flags.render_dirty_full) null else self.dirty;

			try r.render(
				self,
				&commands,
				area
			);
			if (@import("build_options").debug) {
				std.debug.print("area: {}\nflags: {}\n", .{if (self.dirty != null) self.dirty.? else types.ZBounds.zero(), self.flags});
				std.debug.print("total commands: {}\n", .{commands.commands.items.len});
			}

			if (area != null) {
				// to opengl coordinates
				area.?.y = self.getBounds().h - area.?.h - area.?.y;
			}
			try root.renderer.clip(area);
			try root.renderer.clear(root.color.GREY);
			try root.renderer.renderCommands(self.context, &commands);
		}
		try root.renderer.clip(null);

		self.flags.render_dirty = false;
		self.flags.render_dirty_full = false;
		self.dirty = null;

		try root.renderer.resourcesUpdate();
	}
};
