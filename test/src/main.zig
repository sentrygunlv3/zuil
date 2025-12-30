const std = @import("std");
const print = std.debug.print;

const zuil = @import("zuil");
const colors = zuil.color;

const widgets = zuil.widgets;

pub fn main() anyerror!void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator: std.mem.Allocator = gpa.allocator();

	try zuil.init(allocator);
	defer zuil.deinit();

	_ = zuil.svg.svgToBitmap("", 1, 1) catch {};

	const list =
	widgets.list()
	.layout(.fill)
	.children(.{
		widgets.container()
		.layout(.fill)
		.bounds(0, 0, 20, 500)
		.margin(10, 10, 10, 10)
		.color(colors.rgb(0, 1.0, 0.5))
		.build(),
		widgets.container()
		.bounds(50, -50, 50, 50)
		.color(colors.RED)
		.layout(.absolute)
		.build(),
		widgets.container()
		.bounds(0, 0, 20, 500)
		.color(colors.WHITE)
		.build(),
		widgets.list()
		.direction(.vertical)
		.layout(.fill)
		.margin(1, 1, 1, 1)
		.spacing(1)
		.children(.{
			widgets.container()
			.layout(.fill)
			.eventCallback(containerClick)
			.build(),
			widgets.container()
			.layout(.fill)
			.build(),
			widgets.container()
			.layout(.fill)
			.build()
		})
		.build()
	})
	.build();

	const root =
	widgets.container()
	.bounds(0, 0, 400, 225)
	.color(colors.WHITE)
	.child(
		widgets.container()
		.layout(.fill)
		.margin(5, 5, 5, 5)
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
	window.content_alignment = zuil.types.ZAlign.top;
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
				self.content_alignment = .center;
			} else {
				self.content_alignment = .top;
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
			}
		},
		else => {}
	}
	return;
}
