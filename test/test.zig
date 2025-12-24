const std = @import("std");
const print = std.debug.print;

const ui = @import("zuil");
const colors = ui.color;

const widgets = ui.widgets;

pub fn main() anyerror!void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator: std.mem.Allocator = gpa.allocator();

	try ui.init(allocator);
	defer ui.deinit();

	const root = widgets.container()
		.bounds(0, 0, 400, 225)
		.color(colors.WHITE)
		.child(
			widgets.container()
			.layout(.fill)
			.margin(5, 5, 5, 5)
			.color(colors.GREY)
			.child(
				widgets.list()
				.layout(.fill)
				.direction(.horizontal)
				.children(.{
					widgets.container()
					.bounds(0, 0, 20, 500)
					.margin(10, 10, 10, 0)
					.color(colors.rgb(0, 1.0, 0.5))
					.build()
					,
					widgets.container()
					.bounds(50, -50, 50, 50)
					.color(colors.RED)
					.layout(.absolute)
					.build()
					,
					widgets.container()
					.bounds(0, 0, 20, 500)
					.color(colors.WHITE)
					.build()
				})
				.build()
			)
			.build()
		)
		.build();

	const window = try ui.UWindow.init(
		800,
		450,
		"hello",
		root
	);
	window.content_alignment = ui.types.UAlign.top;

	ui.run() catch |e| {
		std.log.err("test: {}", .{e});
	};
}
