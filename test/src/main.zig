const std = @import("std");
const print = std.debug.print;

const zuil = @import("zuil");
const colors = zuil.core.color;

const widgets = zuil.widgets;

pub fn main(init: std.process.Init) anyerror!void {
	const alloc = init.gpa;

	const theme = try zuil.core.Theme.init(alloc);
	defer theme.deinit(alloc);
	try widgets.addStyles(alloc, theme);

	try zuil.init(alloc, theme);
	defer zuil.deinit();

	try zuil.assets.registerAssetComptime("icon.svg", @embedFile("icon.svg"), .svg);
	try zuil.assets.registerAssetComptime("firesans.ttf", @embedFile("font/FiraSans-Regular.ttf"), .ttf);

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
			.color(theme.background)
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
		.c.margin(.new(10))
		.color(.TRANSPARENT)
		.child(
			widgets.list(zuil.app.context)
			.c.size(.fill, .fill)
			.direction(.vertical)
			.spacing(1)
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
					.build()
				)
				.build(),
			})
			.build(),
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

	const font = try zuil.core.font.ttfToFont(zuil.app.context, try zuil.assets.getAsset("firesans.ttf"), 0, 0);
	try zuil.app.context.fonts.put(alloc, "firesans", font);

	zuil.run() catch |e| {
		std.log.err("test: {}", .{e});
	};
}

fn processInput(self: *zuil.ZWindow, event: zuil.input.ZEvent) bool {
	_ = self;
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
		else => {}
	}
	return true;
}

fn containerClick(self: *zuil.core.widget.ZWidget, event: zuil.core.input.ZEvent) void {
	if (event.* != zuil.input.ZEvent.mouse) {
		return 0;
	} else if (event.*.mouse.action != .release) {
		return 0;
	}
	switch (event.*.mouse.key) {
		.left => {
			if (self.getData(widgets.zcontainer.ZContainer)) |data| {
				if (colors.compare(data.color, colors.BLUE)) {
					data.color = colors.BLACK;
				} else {
					data.color = colors.BLUE;
				}
				self.markDirtyRender();
			}
		},
		else => {}
	}
	return 0;
}
