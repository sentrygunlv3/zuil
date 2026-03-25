const std = @import("std");
const print = std.debug.print;

const zuil = @import("zuil");
const colors = zuil.core.color;

const widgets = zuil.widgets;

pub fn main() anyerror!void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator = gpa.allocator();

	try zuil.init(allocator);
	defer zuil.deinit();

	try zuil.assets.registerAssetComptime("icon.svg", @embedFile("icon.svg"), .svg);
	try zuil.assets.registerAssetComptime("firesans.ttf", @embedFile("font/FiraSans-Regular.ttf"), .ttf);

	const list =
	widgets.list(zuil.app.context)
	.c.size(.fill, .fill)
	.children(.{
		widgets.container(zuil.app.context)
		.c.size(.{.dp = 20}, .{.dp = 500})
		.color(colors.rgb(0, 1.0, 0.5))
		.build(),
		widgets.container(zuil.app.context)
		.c.size(.{.pixel = 50}, .{.pixel = 50})
		.color(colors.RED)
		.radius(50)
		.build(),
		widgets.container(zuil.app.context)
		.c.size(.{.dp = 20}, .{.dp = 500})
		.color(colors.WHITE)
		.build(),
		widgets.list(zuil.app.context)
		.c.size(.fill, .fill)
		.direction(.vertical)
		.spacing(1)
		.children(.{
			widgets.icon(zuil.app.context)
			.c.size(.{.dp = 200}, .{.dp = 200})
			.c.keepSizeRatio(true)
			.icon("icon.svg")
			.build(),
			widgets.text(zuil.app.context)
			.c.size(.fill, .{.dp = 60})
			.text("Hello ZUIL!")
			.fontSize(48)
			.build(),
			widgets.container(zuil.app.context)
			.c.size(.{.dp = 50}, .{.dp = 30})
			.color(colors.BLUE)
			.child(
				widgets.text(zuil.app.context)
				.c.size(.fill, .fill)
				.text("button")
				.color(colors.BLACK)
				.build(),
			)
			.build(),
			widgets.container(zuil.app.context)
			.c.size(.{.pixel = 50}, .{.dp = 30})
			.build(),
			widgets.container(zuil.app.context)
			.c.size(.{.mm = 50}, .{.dp = 30})
			.build(),
			widgets.container(zuil.app.context)
			.c.size(.{.percentage = 0.5}, .{.dp = 30})
			.build(),
			widgets.position(zuil.app.context)
			.c.size(.fill, .fill)
			.absolute(true)
			.child(
				widgets.container(zuil.app.context)
				.c.size(.{.dp = 500}, .{.dp = 500})
				.color(colors.RED)
				.build()
			)
			.build(),
		})
		.build()
	})
	.build();

	const root =
	widgets.container(zuil.app.context)
	.c.size(.{.dp = 1200}, .fill)
	.color(colors.WHITE)
	.radius(0)
	.child(
		widgets.container(zuil.app.context)
		.c.size(.fill, .fill)
		.c.margin(.new(10))
		.color(colors.GREY)
		.child(
			widgets.container(zuil.app.context)
			.c.size(.fill, .fill)
			.c.margin(.new(10))
			.color(colors.TRANSPARENT)
			.child(list)
			.build()
		)
		.build()
	)
	.build();

	const window = try zuil.ZWindow.init(
		800,
		450,
		"hello",
		root
	);
	window.input_handler = processInput;

	const font = try zuil.core.font.ttfToFont(zuil.app.context, try zuil.assets.getAsset("firesans.ttf"), 0, 0);
	try zuil.app.context.fonts.put(allocator, "firesans", font);

	zuil.run() catch |e| {
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
		.space => {
			if (self.tree.root) |r| {
				if (r.size.w == .percentage) {
					r.size.w = .{.dp = 1200};
				} else {
					r.size.w = .{.percentage = 1};
				}
				r.markDirty();
			}

			return false;
		},
		.fn_1 => {
			_ = zuil.ZWindow.init(
				400,
				200,
				"child window",
				widgets.container(zuil.app.context)
				.c.size(.fill, .fill)
				.color(colors.BLACK)
				.child(
					widgets.container(zuil.app.context)
					.c.size(.fill, .fill)
					.c.margin(.new(20))
					.color(colors.BLUE)
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
