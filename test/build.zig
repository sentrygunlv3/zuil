const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const zuil = b.dependency("zuil", .{
		.target = target,
		.optimize = optimize,
	});

	const exe = b.addExecutable(.{
		.name = "test",
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/main.zig"),
			.target = target,
			.optimize = optimize,
			.imports = &.{
				.{
					.name = "zuil",
					.module = zuil.module("root"),
				}
			}
		}),
	});
	exe.root_module.linkLibrary(zuil.artifact("zuil"));

	b.installArtifact(exe);

	const run_exe = b.addRunArtifact(exe);

	const run_step = b.step("run", "Run the application");
	run_step.dependOn(&run_exe.step);
}
