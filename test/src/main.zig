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
	.c.layout(.fill)
	.children(.{
		widgets.container()
		.c.layout(.fill)
		.c.size(.{.dp = 20}, .{.dp = 500})
		.c.margin(.{.dp = 10}, .{.dp = 10}, .{.dp = 10}, .{.dp = 10})
		.color(colors.rgb(0, 1.0, 0.5))
		.build(),
		widgets.container()
		.c.position(.{.dp = 50}, .{.dp = -50})
		.c.size(.{.dp = 50}, .{.dp = 50})
		.color(colors.RED)
		.c.layout(.absolute)
		.build(),
		widgets.container()
		.c.size(.{.dp = 20}, .{.dp = 500})
		.color(colors.WHITE)
		.build(),
		widgets.list()
		.direction(.vertical)
		.c.layout(.fill)
		.c.margin(.{.dp = 1}, .{.dp = 1}, .{.dp = 1}, .{.dp = 1})
		.spacing(1)
		.children(.{
			widgets.icon()
			.c.layout(.fill)
			.icon("icon.svg")
			.build(),
			widgets.container()
			.c.size(.{.dp = 50}, .{.dp = 30})
			.c.eventCallback(containerClick)
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
		})
		.build()
	})
	.build();

	const root =
	widgets.container()
	.c.size(.{.dp = 1200}, .{.percentage = 1})
	.color(colors.WHITE)
	.child(
		widgets.container()
		.c.layout(.fill)
		.c.margin(.{.dp = 5}, .{.dp = 5}, .{.dp = 5}, .{.dp = 5})
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
	window.content_alignment = zuil.types.ZAlign.center;
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
			if (self.content_alignment != .center) {
				self.setContentAlignment(.center);
			} else {
				self.setContentAlignment(.left);
			}
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
				self.markDirty();
			}
		},
		else => {}
	}
	return;
}
