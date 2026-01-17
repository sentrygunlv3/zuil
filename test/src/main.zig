const std = @import("std");
const print = std.debug.print;

const zuil = @import("zuil");
const colors = zuil.core.color;

const widgets = zuil.widgets;

pub fn main() anyerror!void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator: std.mem.Allocator = gpa.allocator();

	try zuil.init(allocator);
	defer zuil.deinit();

	try zuil.assets.registerAssetComptime("icon.svg", @embedFile("icon.svg"), .svg);

	const list =
	widgets.list()
	.c.size(.fill(), .fill())
	.children(.{
		widgets.container()
		.c.size(.{.dp = 20}, .{.dp = 500})
		.color(colors.rgb(0, 1.0, 0.5))
		.build(),
		widgets.container()
		.c.size(.{.dp = 50}, .{.dp = 50})
		.color(colors.RED)
		.build(),
		widgets.container()
		.c.size(.{.dp = 20}, .{.dp = 500})
		.color(colors.WHITE)
		.build(),
		widgets.list()
		.c.size(.fill(), .fill())
		.direction(.vertical)
		.spacing(1)
		.children(.{
			widgets.icon()
			.c.size(.{.dp = 200}, .{.dp = 200})
			.c.keepSizeRatio(true)
			.icon("icon.svg")
			.build(),
			widgets.container()
			.c.size(.{.dp = 50}, .{.dp = 30})
			.c.eventCallback(containerClick)
			.color(colors.BLUE)
			.build(),
			widgets.container()
			.c.size(.{.pixel = 50}, .{.dp = 30})
			.build(),
			widgets.container()
			.c.size(.{.mm = 50}, .{.dp = 30})
			.build(),
			widgets.container()
			.c.size(.{.percentage = 0.5}, .{.dp = 30})
			.build(),
			widgets.position()
			.c.size(.fill(), .fill())
			.absolute(true)
			.child(
				widgets.container()
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
	widgets.container()
	.c.size(.{.dp = 1200}, .fill())
	.color(colors.WHITE)
	.child(
		widgets.container()
		.c.size(.fill(), .fill())
		.c.margin(.new(20))
		.color(colors.GREY)
		.child(list)
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

	zuil.run() catch |e| {
		std.log.err("test: {}", .{e});
	};
}

fn processInput(self: *zuil.ZWindow, event: zuil.input.ZEvent) bool {
	std.debug.print("{}\n", .{event});
	if (event != zuil.input.ZEvent.key) {
		return true;
	} else if (event.key.action != .release) {
		return true;
	}
	switch (event.key.key) {
		.space => {
			if (self.root) |r| {
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
				widgets.container()
				.c.size(.fill(), .fill())
				.color(colors.BLACK)
				.child(
					widgets.container()
					.c.size(.fill(), .fill())
					.c.margin(.new(20))
					.color(colors.BLUE)
					.build()
				)
				.build()
			) catch |e| {
				std.debug.print("{}\n", .{e});
			};
			return false;
		},
		else => {}
	}
	return true;
}

fn containerClick(self: *zuil.zwidget.ZWidget, event: zuil.input.ZEvent) anyerror!void {
	if (event != zuil.input.ZEvent.mouse) {
		return;
	} else if (event.mouse.action != .release) {
		return;
	}
	switch (event.mouse.key) {
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
	return;
}
