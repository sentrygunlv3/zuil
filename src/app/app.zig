const std = @import("std");
pub const opengl = @import("opengl");
pub const gl = opengl.bindings;
pub const c = @import("c");

pub const ZuilCore = @import("zuilcore");

pub const input = @import("input.zig");
pub const ZWindow = @import("window.zig").ZWindow;

pub const backend = @import("backend/opengl.zig");

pub const ZAppError = error{
	NoWindowsCreated,
	MainWindowSetButNull,
	SDLError,
};

const root = @import("root");

pub const State = struct {
	gpa: std.heap.DebugAllocator(.{}),
	alloc: std.mem.Allocator,
	threaded: std.Io.Threaded,
	io: std.Io,

	context: *ZuilCore.ZContext = undefined,

	backend_data: backend.BackendData = .{},
	windows: std.AutoHashMap(u32, *ZWindow),
	main_window: union(enum) {
		// main window was never set
		not_set: void,
		// main window was set
		set: ?*ZWindow,
	} = .{.set = null},

	modifiers: ZuilCore.input.ZModifiers = .{},
};

fn errorCallback(s: ?*anyopaque, category: c_int, priority: c_uint, message: [*c]const u8) callconv(.c) void {
	const state: *State = @alignCast(@ptrCast(s.?));
	state.context.log(
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

pub export fn SDL_AppInit(
	state: **anyopaque,
	argc: c_int,
	argv: [*c][*c]u8,
) callconv(.c) c.SDL_AppResult {
	_ = argc; _ = argv;

	const s = std.heap.c_allocator.create(State) catch {
		return c.SDL_APP_FAILURE;
	};
	s.* = .{
		.gpa = .init,
		.alloc = s.gpa.allocator(),
		.threaded = .init(s.alloc, .{}),
		.io = s.threaded.io(),
		.windows = .init(s.alloc),
	};
	s.context = ZuilCore.ZContext.init(s.alloc, s.io, undefined) catch {
		return c.SDL_APP_FAILURE;
	};

	state.* = @ptrCast(s);
	c.SDL_SetLogOutputFunction(errorCallback, s);

	backend.init(s) catch |e| {
		std.debug.print("backend error {}\n", .{e});
		return c.SDL_APP_FAILURE;
	};

	root.zuilMain(s) catch {
		return c.SDL_APP_FAILURE;
	};
	return c.SDL_APP_CONTINUE;
}

pub export fn SDL_AppEvent(
	s: *anyopaque,
	event: *c.SDL_Event,
) callconv(.c) c.SDL_AppResult {
	const state: *State = @alignCast(@ptrCast(s));

	switch (event.type) {
		c.SDL_EVENT_WINDOW_CLOSE_REQUESTED => {
			const window = state.windows.get(event.window.windowID) orelse return c.SDL_APP_CONTINUE;
			window.deinit(state);
			if (state.main_window == .set and state.main_window.set == null) {
				return c.SDL_APP_SUCCESS;
			}
		},
		c.SDL_EVENT_MOUSE_BUTTON_DOWN, c.SDL_EVENT_MOUSE_BUTTON_UP => {
			const window = state.windows.get(event.button.windowID) orelse return c.SDL_APP_CONTINUE;
			window.tree.key_events.append(state.alloc, .{
				.mouse = .{
					.key = input.mouseKeyFromSDL(event.button.button),
					.clicks = event.button.clicks,
					.action = input.actionFromSDL(event.button.down, false),
					.modifiers = state.modifiers,
					.x = event.button.x,
					.y = event.button.y,
				}
			}) catch return c.SDL_APP_CONTINUE;
		},
		c.SDL_EVENT_KEY_DOWN, c.SDL_EVENT_KEY_UP => {
			const window = state.windows.get(event.key.windowID) orelse return c.SDL_APP_CONTINUE;
			window.tree.key_events.append(state.alloc, .{
				.key = .{
					.key = input.keyFromSDL(event.key.key),
					.scan_code = @intCast(event.key.scancode),
					.action = input.actionFromSDL(event.key.down, event.key.repeat),
					.modifiers = state.modifiers,
				}
			}) catch return c.SDL_APP_CONTINUE;
		},
		c.SDL_EVENT_WINDOW_FOCUS_GAINED => {
			const window = state.windows.get(event.key.windowID) orelse return c.SDL_APP_CONTINUE;
			window.tree.flags.focused = true;
			window.tree.markDirtyRender(window.tree.current_bounds);
		},
		c.SDL_EVENT_WINDOW_FOCUS_LOST => {
			const window = state.windows.get(event.key.windowID) orelse return c.SDL_APP_CONTINUE;
			window.tree.flags.focused = false;
			window.tree.markDirtyRender(window.tree.current_bounds);
		},
		c.SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED => {
			const window = state.windows.get(event.window.windowID) orelse return c.SDL_APP_CONTINUE;
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
			const window = state.windows.get(event.window.windowID) orelse return c.SDL_APP_CONTINUE;
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

	return c.SDL_APP_CONTINUE;
}

pub export fn SDL_AppIterate(
	s: *anyopaque,
) callconv(.c) c.SDL_AppResult {
	const state: *State = @alignCast(@ptrCast(s));

	if (state.main_window == .set and state.main_window.set == null) {
		return c.SDL_APP_SUCCESS;
	}

	var iterator = state.windows.valueIterator();
	while (iterator.next()) |window| {
		const value = window.*.process(state) catch |e| {
			state.context.log(.err, "{}", .{e});
			continue;
		};
		if (!value) {
			window.*.deinit(state);
			break;
		}
	}
	c.SDL_Delay(16);

	return c.SDL_APP_CONTINUE;
}

pub export fn SDL_AppQuit(
	s: *anyopaque,
	result: c.SDL_AppResult,
) callconv(.c) void {
	_ = result;
	const state: *State = @alignCast(@ptrCast(s));

	state.windows.deinit();

	state.context.log(.info, "ZUIL deinit", .{});
	state.context.deinit();

	backend.deinit(state);
}
