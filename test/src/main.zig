const std = @import("std");

const zuil = @import("zuil");
const colors = zuil.core.color;

const widgets = zuil.widgets;

var number: u32 = 0;

pub fn main(init: std.process.Init) anyerror!void {
	const alloc = init.gpa;

	const theme = try zuil.core.Theme.init(alloc);
	defer theme.deinit(alloc);
	try widgets.addStyles(alloc, theme);

	zuil.assets.init(alloc);
	defer zuil.assets.deinit();

	try zuil.app.init(alloc, theme);
	defer zuil.app.deinit();

	zuil.app.createContext = &zuil.widgets.registerShader;

	try zuil.widgets.register(zuil.app.context);

	try zuil.assets.registerAssetComptime("icon.svg", @embedFile("icon.svg"), .svg);
	try zuil.assets.registerAssetComptime("firesans.ttf", @embedFile("font/FiraSans-Regular.ttf"), .ttf);

	const widgets_theme: *widgets.Style = @alignCast(@ptrCast(theme.get(@typeName(widgets.Style)) orelse {
		zuil.app.context.log(.err, "failed to get style {s}", .{@typeName(widgets.Style)});
		return;
	}));

	const list =
	widgets.list(zuil.app.context)
	.c.size(.fill, .fill)
	.direction(.vertical)
	.children(.{
		widgets.container(zuil.app.context)
		.c.size(.{.pixel = 250}, .{.pixel = 250})
		.c.keepSizeRatio(true)
		.color(.BLACK)
		.radius(250)
		.child(
			widgets.position(zuil.app.context)
			.c.size(.fill, .fill)
			.alignment(true)
			.child(
				widgets.icon(zuil.app.context)
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
	widgets.list(zuil.app.context)
	.c.size(.fill, .fill)
	.children(.{
		widgets.container(zuil.app.context)
		.c.size(.{.pixel = 300}, .fill)
		.radius(0)
		.child(
			widgets.container(zuil.app.context)
			.c.size(.fill, .fill)
			.c.margin(.new(10))
			.color(widgets_theme.background)
			.child(
				widgets.container(zuil.app.context)
				.c.size(.fill, .fill)
				.c.margin(.new(10))
				.color(.TRANSPARENT)
				.child(list)
				.build()
			)
			.build()
		)
		.build(),
		widgets.container(zuil.app.context)
		.c.size(.fill, .fill)
		.c.margin(.new(4))
		.color(.TRANSPARENT)
		.child(
			widgets.list(zuil.app.context)
			.c.size(.fill, .fill)
			.direction(.vertical)
			.spacing(.{ .dp = 4 })
			.children(.{
				widgets.text(zuil.app.context)
				.c.size(.fill, .{.dp = 60})
				.text("Hello ZUIL!")
				.fontSize(48)
				.build(),
				widgets.container(zuil.app.context)
				.c.size(.{.dp = 50}, .{.dp = 30})
				.child(
					widgets.text(zuil.app.context)
					.c.size(.fill, .fill)
					.text("50 dp")
					.build(),
				)
				.build(),
				widgets.container(zuil.app.context)
				.c.size(.{.pixel = 50}, .{.dp = 30})
				.child(
					widgets.text(zuil.app.context)
					.c.size(.fill, .fill)
					.text("50 pixels")
					.build(),
				)
				.build(),
				// the mm units seem correct on my display
				// but i havent actually tried this on other displays
				widgets.container(zuil.app.context)
				.c.size(.{.mm = 50}, .{.dp = 30})
				.child(
					widgets.text(zuil.app.context)
					.c.size(.fill, .fill)
					.text("50 mm")
					.build(),
				)
				.build(),
				widgets.container(zuil.app.context)
				.c.size(.{.percentage = 0.5}, .{.dp = 30})
				.child(
					widgets.text(zuil.app.context)
					.c.size(.fill, .fill)
					.text("50 %")
					.build(),
				)
				.build(),
				widgets.position(zuil.app.context)
				.c.size(.fill, .fill)
				.absolute(true)
				.child(
					widgets.container(zuil.app.context)
					.c.size(.{.dp = 500}, .{.dp = 500})
					.color(.RED)
					.child(
						widgets.button(zuil.app.context)
						.c.size(.{.dp = 100}, .{.dp = 50})
						.c.margin(.new(5))
						.setOnClick(containerClick)
						.child(
							widgets.text(zuil.app.context)
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
		800,
		450,
		"hello",
		root,
	);
	window.input_handler = processInput;

	const font = try zuil.widgets.font.ttfToFont(zuil.app.context, try zuil.assets.getAsset("firesans.ttf"), 0, 0);
	const w = zuil.app.context.getSubcontext(zuil.widgets.NAME) orelse {
		zuil.app.context.log(.err, "failed to get widgets subcontext", .{});
		return;
	};
	const widget_context: *zuil.widgets.ZWidgetContext = @ptrCast(@alignCast(w));
	try widget_context.fonts.put(alloc, "firesans", font);

	zuil.app.run() catch |e| {
		std.log.err("test: {}", .{e});
	};
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
				400,
				200,
				"child window",
				widgets.container(zuil.app.context)
				.c.size(.fill, .fill)
				.color(.BLACK)
				.child(
					widgets.container(zuil.app.context)
					.c.size(.fill, .fill)
					.c.margin(.new(20))
					.color(.BLUE)
					.build()
				)
				.build()
			) catch |e| {
				zuil.app.context.log(.debug, "{}", .{e});
			};
			return false;
		},
		.space => {
			if (zuil.app.context.theme.background.equals(.BLACK)) {
				zuil.app.context.theme.background = .rgb256(41, 44, 48);
			} else {
				zuil.app.context.theme.background = .BLACK;
			}
			self.tree.markDirtyRender(self.tree.current_bounds);
		},
		else => {}
	}
	return true;
}

fn containerClick(self: *zuil.widgets.zbutton.ZButton, event: zuil.core.input.ZMouseEvent) void {
	if (event.key != .left or event.action != .press) return;

	number += 1;

	self.color = .rgb256(0, 0, number);
	self.super.markDirtyRender();

	if (self.child) |child| {
		const text = child.asSafe(widgets.ztext.ZText) orelse return;

		if (text.text != null) {
			self.super.window.?.context.allocator.free(text.text.?);
		}
		text.text = std.fmt.allocPrint(self.super.window.?.context.allocator, "{d}", .{number}) catch null;
	}
}
