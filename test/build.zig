const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const zuil = b.dependency("zuil", .{.debug = b.option(bool, "debug", "enable debug") orelse false});

	const exe = b.addExecutable(.{
		.name = "test",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/main.zig"),
			.target = target,
			.optimize = optimize,
		}),
	});
	exe.root_module.addImport("zuil", zuil.module("root"));
	exe.linkLibrary(zuil.artifact("zuil"));

	b.installArtifact(exe);
}
