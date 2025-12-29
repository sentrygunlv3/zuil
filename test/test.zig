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

	const root =
	widgets.container()
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
	window.input_handler = process_input;

	ui.run() catch |e| {
		std.log.err("test: {}", .{e});
	};
}

fn process_input(self: *ui.UWindow, event: ui.input.UEvent) bool {
	std.debug.print("{}\n", .{event});
	if (event != ui.input.UEvent.key) {
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
			self.dirty = true;
			return false;
		},
		else => {}
	}
	return true;
}
