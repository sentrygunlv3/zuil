const std = @import("std");
const root = @import("app.zig");
const c = @import("c");

const input = root.ZuilCore.input;
const widget = root.ZuilCore.widget;
const types = root.ZuilCore.types;

pub const ZWindow = struct {
	window: *c.SDL_Window = undefined,
	tree: *root.ZuilCore.tree.ZWidgetTree = undefined,
	painter: root.ZuilCore.context.ZPainter = undefined,
	input_handler: ?*const fn (self: *@This(), event: input.ZEvent) bool = null,

	posx: f32 = 0,
	posy: f32 = 0,

	pub fn init(width: u32, height: u32, title: [:0]const u8, root_widget: ?*widget.ZWidget) !*@This() {
		const self = try root.allocator.create(@This());
		errdefer self.deinit();

		self.* = .{};

		try root.backend.createWindow(self, width, height, title);
		errdefer root.backend.destroyWindow(self);

		//var size_x: f32 = 0;
		//var size_y: f32 = 0;
		//if (glfw.getPrimaryMonitor()) |monitor| {
			//const mode = try monitor.getVideoMode();
			//const size = try monitor.getPhysicalSize();

			//size_x = @as(f32, @floatFromInt(mode.width)) / @as(f32, @floatFromInt(size[0]));
			//size_y = @as(f32, @floatFromInt(mode.height)) / @as(f32, @floatFromInt(size[1]));
		//}

		const scaling = c.SDL_GetWindowDisplayScale(self.window);

		self.tree = try .init(
			.{.w = 1, .h = 1},
			scaling,
			root_widget,
			root.context,
			&self.painter,
		);

		var w: c_int = 0;
		var h: c_int = 0;
		_ = c.SDL_GetWindowSizeInPixels(self.window, &w, &h);
		self.tree.current_bounds = .{
			.x = 0,
			.y = 0,
			.w = @floatFromInt(w),
			.h = @floatFromInt(h),
		};

		try root.windows.put(@intCast(c.SDL_GetWindowID(self.window)), self);
		return self;
	}

	pub fn deinit(self: *@This()) void {
		if (root.main_window == .set and root.main_window.set == self) root.main_window = .{ .set = null };
		self.tree.deinit();
		_ = root.windows.remove(@intCast(c.SDL_GetWindowID(self.window)));
		root.backend.destroyWindow(self);
		root.allocator.destroy(self);
	}

	pub fn process(self: *@This()) !bool {
		if (self.tree.root) |r| {
			const focused = c.SDL_GetMouseFocus();
			var posx: f32 = 0;
			var posy: f32 = 0;
			_ = c.SDL_GetMouseState(&posx, &posy);
			if (
				focused == self.window and
				(self.posx != posx or self.posy != posy)
			) {
				if (r.isOverPoint(@floatCast(posx), @floatCast(posy), false)) |hovered| {
					//root.context.log(.debug, "hovered {*} at x {} - y {}", .{hovered, posx, posy});
					if (self.tree.last_hover != null) {
						if (self.tree.last_hover.? != hovered) {
							try self.tree.last_hover.?.event(.{.mouse_move = .{
								.entered = false,
								.x = @floatCast(posx),
								.y = @floatCast(posy),
							}});
							self.tree.last_hover = hovered;
							try hovered.event(.{.mouse_move = .{
								.entered = true,
								.x = @floatCast(posx),
								.y = @floatCast(posy),
							}});
						}
					} else {
						self.tree.last_hover = hovered;
						try hovered.event(.{.mouse_move = .{
							.entered = true,
							.x = @floatCast(posx),
							.y = @floatCast(posy),
						}});
					}
				} else {
					self.tree.last_hover = null;
					//root.context.log(.debug, "nothing hovered", .{});
				}
			}
			self.posx = posx;
			self.posy = posy;
		}
		if (self.tree.key_events.items.len != 0) {
			root.context.log(.debug, "--- process input ---", .{});
			for (self.tree.key_events.items) |event| {
				if (self.input_handler) |func| {
					if (!func(self, event)) {
						continue;
					}
				}
				switch (event) {
					.key => {
						if (self.tree.focused_widget) |focused| {
							root.context.log(.debug, "{*}", .{focused});
							try focused.event(event);
						}
					},
					.mouse => {
						if (self.tree.root) |r| {
							if (r.isOverPoint(event.mouse.x, event.mouse.y, false)) |hovered| {
								root.context.log(.debug, "click at x {} - y {} hit {*}", .{event.mouse.x, event.mouse.y, hovered});
								try hovered.event(event);
							} else {
								root.context.log(.debug, "nothing hovered", .{});
							}
						}
					},
					else => {}
				}
			}
			self.tree.key_events.clearAndFree(root.allocator);
		}

		if (self.tree.flags.layout_dirty) {
			root.context.log(.debug, "--- process layout ---", .{});

			try self.tree.layout();
		}
		if (self.tree.flags.layout_dirty or self.tree.flags.render_dirty) {
			root.context.log(.debug, "--- process render ---", .{});

			try self.tree.render();
		}
		return true;
	}
};
