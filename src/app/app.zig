const std = @import("std");
pub const opengl = @import("opengl");
pub const gl = opengl.bindings;
pub const c = @import("c");

pub const ZuilCore = @import("zuilcore");

pub const input = @import("input.zig");
pub const ZWindow = @import("window.zig").ZWindow;

pub const backend = @import("backend/opengl.zig");

pub var allocator: std.mem.Allocator = undefined;
pub var context: *ZuilCore.ZContext = undefined;

pub var windows: std.AutoHashMap(u32, *ZWindow) = undefined;
pub var main_window: ?*ZWindow = null;

pub var modifiers = ZuilCore.input.ZModifiers{};

pub var createContext: ?*const fn (context: *ZuilCore.ZContext) anyerror!void = null;

pub const ZAppError = error{
	NoWindowsCreated,
	SDLError,
};

pub fn init(a: std.mem.Allocator, io: std.Io, theme: *ZuilCore.Theme) !void {
	allocator = a;

	context = try ZuilCore.ZContext.init(allocator, io, &backend.ZRenderFIOpengl, theme);

	c.SDL_SetLogOutputFunction(errorCallback, null);

	if (!c.SDL_Init(c.SDL_INIT_VIDEO)) return ZAppError.SDLError;

	try backend.init();

	if (createContext) |func| {
		try func(context);
	}

	windows = .init(allocator);

	context.log(.info, "ZUIL init", .{});
}

pub fn deinit() void {
	windows.deinit();

	context.log(.info, "ZUIL deinit", .{});
	context.deinit();

	backend.deinit();
}

pub fn run() !void {
	if (windows.count() == 0) {
		return ZAppError.NoWindowsCreated;
	}

	var running = true;
	while (running) {
		if (main_window == null) {
			running = false;
			break;
		}

		var event: c.SDL_Event = undefined;
		while (c.SDL_PollEvent(&event)) {
			switch (event.type) {
				c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => {
					const window = windows.get(event.window.windowID) orelse continue;
					window.deinit();
					if (main_window == null) {
						running = false;
						break;
					}
				},
				c.SDL_EVENT_MOUSE_BUTTON_DOWN, c.SDL_EVENT_MOUSE_BUTTON_UP => {
					const window = windows.get(event.button.windowID) orelse continue;
					window.tree.key_events.append(allocator, .{
						.mouse = .{
							.key = input.mouseKeyFromSDL(event.button.button),
							.clicks = event.button.clicks,
							.action = input.actionFromSDL(event.button.down, false),
							.modifiers = modifiers,
							.x = event.button.x,
							.y = event.button.y,
						}
					}) catch continue;
				},
				c.SDL_EVENT_KEY_DOWN, c.SDL_EVENT_KEY_UP => {
					const window = windows.get(event.key.windowID) orelse continue;
					window.tree.key_events.append(allocator, .{
						.key = .{
							.key = input.keyFromSDL(event.key.key),
							.scan_code = @intCast(event.key.scancode),
							.action = input.actionFromSDL(event.key.down, event.key.repeat),
							.modifiers = modifiers,
						}
					}) catch continue;
				},
				c.SDL_EVENT_WINDOW_FOCUS_GAINED => {
					const window = windows.get(event.key.windowID) orelse continue;
					window.tree.flags.focused = true;
					window.tree.markDirtyRender(window.tree.current_bounds);
				},
				c.SDL_EVENT_WINDOW_FOCUS_LOST => {
					const window = windows.get(event.key.windowID) orelse continue;
					window.tree.flags.focused = false;
					window.tree.markDirtyRender(window.tree.current_bounds);
				},
				c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
					const window = windows.get(event.window.windowID) orelse continue;
					if (window.tree.root) |r| {
						r.markDirty();
					}
					window.tree.flags.render_dirty_full = true;

					window.tree.current_bounds = .{
						.x = 0,
						.y = 0,
						.w = @floatFromInt(event.window.data1),
						.h = @floatFromInt(event.window.data2),
					};

					backend.updateSize(window);
				},
				c.SDL_EVENT_WINDOW_DISPLAY_SCALE_CHANGED => {
					const window = windows.get(event.window.windowID) orelse continue;
					if (window.tree.root) |r| {
						r.markDirty();
					}
					window.tree.flags.render_dirty_full = true;

					const scaling = c.SDL_GetWindowDisplayScale(window.window);
					window.tree.scaling = scaling;

					backend.updateSize(window);
				},
				else => {}
			}
		}

		var iterator = windows.valueIterator();
		while (iterator.next()) |window| {
			const value = window.*.process() catch |e| {
				context.log(.err, "{}", .{e});
				return;
			};
			if (!value) {
				window.*.deinit();
				break;
			}
		}
	}
}

fn errorCallback(_: ?*anyopaque, category: c_int, priority: c_uint, message: [*c]const u8) callconv(.c) void {
	context.log(
		switch (priority) {
			c.SDL_LOG_PRIORITY_DEBUG => .debug,
			c.SDL_LOG_PRIORITY_ERROR, c.SDL_LOG_PRIORITY_CRITICAL => .err,
			c.SDL_LOG_PRIORITY_WARN => .warning,
			else => .info,
		},
		"SDL3 {d} {s}",
		.{category, message}
	);
}
