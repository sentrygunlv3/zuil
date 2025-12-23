const std = @import("std");
const print = std.debug.print;

const ui = @import("zuil");
const colors = ui.color;

const container = ui.uContainer;
const list = ui.UList;

pub fn main() anyerror!void {
	var gpa = std.heap.GeneralPurposeAllocator(.{}){};
	const allocator: std.mem.Allocator = gpa.allocator();

	try ui.init(allocator);
	defer ui.deinit();

	const root = container()
		.bounds(400, 225)
		.color(colors.RED)
		.child(
			list()
			.layout(.fill)
			.content_align(.center)
			.children(.{
				container()
				.bounds(20, 500)
				.color(colors.rgb(0, 1.0, 0.5))
				.build()
				,
				container()
				.bounds(20, 500)
				.color(colors.WHITE)
				.build()
			})
			.build()
		)
		.build();

	const window = try ui.UWindow.init(
		800,
		450,
		"hello",
		root
	);
	window.content_alignment = ui.widget.UAlign.top;

	ui.run() catch |e| {
		std.log.err("test: {}", .{e});
	};
}
