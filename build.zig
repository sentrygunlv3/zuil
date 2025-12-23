const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const glfw = b.dependency("zglfw", .{});
	const opengl = b.dependency("zopengl", .{});

	var lib = b.addLibrary(.{
		.name = "zuil", 
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/root.zig"),
			.target = target,
			.optimize = optimize,
		}),
	});
	lib.root_module.addImport("glfw", glfw.module("root"));
	lib.root_module.addImport("opengl", opengl.module("root"));
	lib.linkLibrary(glfw.artifact("glfw"));

	const exe = b.addExecutable(.{
		.name = "test",
		.root_module = b.createModule(.{
			.root_source_file = b.path("test/test.zig"),
			.target = target,
			.optimize = optimize,
		}),
	});
	exe.root_module.addImport("zuil", lib.root_module);

	b.installArtifact(exe);
}
