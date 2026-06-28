const std = @import("std");

const zuil = @import("zuil");
const colors = zuil.core.color;

const widgets = @import("widgets");

var number: u32 = 0;

// use sdl3 app callbacks
comptime {
	_ = zuil.app;
}
pub const _start = void;

pub fn zuilMain(state: *zuil.app.State) anyerror!void {
	const alloc = state.alloc;

	const theme = try zuil.core.Theme.init(alloc);
	errdefer theme.deinit(alloc);
	try widgets.addStyles(alloc, theme);

	state.context.theme = theme;

	try widgets.register(state.context);

	try zuil.assets.registerAssetComptime("icon.svg", @embedFile("icon.svg"), .svg);
	try zuil.assets.registerAssetComptime("firesans.ttf", @embedFile("font/FiraSans-Regular.ttf"), .ttf);

	const list =
	widgets.list(state.context)
	.c.size(.fill, .fill)
	.direction(.vertical)
	.children(.{
		widgets.container(state.context)
		.c.size(.{.pixel = 250}, .{.pixel = 250})
		.c.keepSizeRatio(true)
		.color(.{.custom = .BLACK})
		.radius(250)
		.child(
			widgets.position(state.context)
			.c.size(.fill, .fill)
			.alignment(true)
			.child(
				widgets.icon(state.context)
				.c.size(.{.pixel = 200}, .{.pixel = 200})
				.c.keepSizeRatio(true)
				.icon("icon.svg")
				.build(),
			)
			.build(),
		)
		.build(),
	})
	.build();

	const root =
	widgets.list(state.context)
	.c.size(.fill, .fill)
	.children(.{
		widgets.container(state.context)
		.c.size(.{.pixel = 300}, .fill)
		.radius(0)
		.child(
			widgets.container(state.context)
			.c.size(.fill, .fill)
			.c.margin(.new(10))
			.color(.background)
			.child(
				widgets.container(state.context)
				.c.size(.fill, .fill)
				.c.margin(.new(10))
				.color(.{.custom = .TRANSPARENT})
				.child(list)
				.build()
			)
			.build()
		)
		.build(),
		widgets.container(state.context)
		.c.size(.fill, .fill)
		.c.margin(.new(4))
		.color(.{.custom = .TRANSPARENT})
		.child(
			widgets.list(state.context)
			.c.size(.fill, .fill)
			.direction(.vertical)
			.spacing(.{ .dp = 4 })
			.children(.{
				widgets.text(state.context)
				.c.size(.fill, .{.dp = 60})
				.text("Hello ZUIL!")
				.fontSize(48)
				.build(),
				widgets.container(state.context)
				.c.size(.{.dp = 50}, .{.dp = 30})
				.child(
					widgets.text(state.context)
					.c.size(.fill, .fill)
					.text("50 dp")
					.build(),
				)
				.build(),
				widgets.container(state.context)
				.c.size(.{.pixel = 50}, .{.dp = 30})
				.child(
					widgets.text(state.context)
					.c.size(.fill, .fill)
					.text("50 pixels")
					.build(),
				)
				.build(),
				// the mm units seem correct on my display
				// but i havent actually tried this on other displays
				widgets.container(state.context)
				.c.size(.{.mm = 50}, .{.dp = 30})
				.child(
					widgets.text(state.context)
					.c.size(.fill, .fill)
					.text("50 mm")
					.build(),
				)
				.build(),
				widgets.container(state.context)
				.c.size(.{.percentage = 0.5}, .{.dp = 30})
				.child(
					widgets.text(state.context)
					.c.size(.fill, .fill)
					.text("50 %")
					.build(),
				)
				.build(),
				widgets.position(state.context)
				.c.size(.fill, .fill)
				.absolute(true)
				.child(
					widgets.container(state.context)
					.c.size(.{.dp = 500}, .{.dp = 500})
					.color(.{.custom = .RED})
					.child(
						widgets.button(state.context)
						.c.size(.{.dp = 100}, .{.dp = 50})
						.c.margin(.new(5))
						.color(.{.custom = .BLACK})
						.colorHover(.{.custom = .GREY})
						.setOnClick(containerClick)
						.child(
							widgets.text(state.context)
							.c.margin(.new(5))
							.c.size(.fill, .fill)
							.c.ignoreInput(true)
							.fontSize(20)
							.text("button")
							.build()
						)
						.build()
					)
					.build()
				)
				.build()
			})
			.build()
		)
		.build()
	})
	.build();

	const window = try zuil.ZWindow.init(
		state,
		800,
		450,
		"hello",
		topBar(state, root),
	);
	window.input_handler = processInput;
	state.main_window = .{.set = window};

	const font = try widgets.font.ttfToFont(state.context, try zuil.assets.getAsset("firesans.ttf"), 0, 0);
	const w = state.context.getSubcontext(widgets.NAME) orelse {
		state.context.log(.err, "failed to get widgets subcontext", .{});
		return;
	};
	const widget_context: *widgets.ZWidgetContext = @ptrCast(@alignCast(w));
	try widget_context.fonts.put(alloc, "firesans", font);
}

fn processInput(self: *zuil.ZWindow, event: zuil.input.ZEvent) bool {
	if (event != zuil.input.ZEvent.key) {
		return true;
	} else if (event.key.action != .release) {
		return true;
	}
	switch (event.key.key) {
		.fn_1 => {
			_ = zuil.ZWindow.init(
				@alignCast(@ptrCast(self.tree.context.usercontext)),
				400,
				200,
				"child window",
				widgets.container(self.tree.context)
				.c.size(.fill, .fill)
				.color(.{ .custom = .BLACK })
				.child(
					widgets.container(self.tree.context)
					.c.size(.fill, .fill)
					.c.margin(.new(20))
					.color(.{ .custom = .BLUE })
					.build()
				)
				.build()
			) catch |e| {
				self.tree.context.log(.debug, "{}", .{e});
			};
			return false;
		},
		.space => {
			if (self.tree.context.theme.background.equals(.BLACK)) {
				self.tree.context.theme.background = .rgb256(41, 44, 48);
			} else {
				self.tree.context.theme.background = .BLACK;
			}
			self.tree.markDirtyRender(self.tree.current_bounds);
		},
		else => {}
	}
	return true;
}

fn containerClick(self: *widgets.zbutton.ZButton, event: zuil.core.input.ZMouseEvent) void {
	if (event.key != .left or event.action != .release) return;

	number += 1;

	self.color.custom = .rgb256(0, 0, number);
	self.super.markDirtyRender();

	if (self.child) |child| {
		const text = child.cast(widgets.ztext.ZText) orelse return;

		if (text.text != null) {
			self.super.window.?.context.allocator.free(text.text.?);
		}
		text.text = std.fmt.allocPrint(self.super.window.?.context.allocator, "{d}", .{number}) catch null;
	}
}

fn topBar(state: *zuil.app.State, content: *zuil.core.widget.ZWidget) *zuil.core.widget.ZWidget {
	return widgets.list(state.context)
	.c.size(.fill, .fill)
	.direction(.vertical)
	.children(.{
		widgets.container(state.context)
		.c.size(.fill, .{ .dp = 25 })
		.color(.background)
		.radius(0)
		.child(
			widgets.list(state.context)
			.c.size(.fill, .fill)
			.c.margin(.new(2))
			.spacing(.{.dp = 2})
			.children(.{
				widgets.button(state.context)
				.c.size(.{.dp = 80}, .fill)
				.setOnClick(gitClick)
				.child(
					widgets.text(state.context)
					.c.size(.fill, .fill)
					.c.margin(.new(4))
					.c.ignoreInput(true)
					.text("github")
					.fontSize(14)
					.build(),
				)
				.build(),
			})
			.build(),
		)
		.build(),
		content,
	})
	.build();
}

fn gitClick(self: *widgets.zbutton.ZButton, event: zuil.core.input.ZMouseEvent) void {
	if (event.key != .left or event.action != .release) return;

	var child = std.process.spawn(
		self.super.window.?.context.io,
		.{.argv = &[_][]const u8{
			"xdg-open",
			"https://github.com/sentrygunlv3/zuil"
	}}) catch |e| {
		self.super.window.?.context.log(.err, "xdg-open failed: {}", .{e});
		return;
	};
	_ = child.wait(self.super.window.?.context.io) catch return;
}
