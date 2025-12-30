const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const glfw = b.dependency("zglfw", .{});
	const opengl = b.dependency("zopengl", .{});

	var lib = b.addLibrary(.{
		.name = "zuil",
		.linkage = .dynamic,
		.root_module = b.createModule(.{
			.root_source_file = b.path("src/root.zig"),
			.target = target,
			.optimize = optimize,
		}),
	});
	lib.root_module.addImport("glfw", glfw.module("root"));
	lib.root_module.addImport("opengl", opengl.module("root"));
	lib.root_module.linkLibrary(glfw.artifact("glfw"));

	lib.root_module.linkSystemLibrary("freetype", .{});

	lib.root_module.linkSystemLibrary("plutosvg", .{});
	lib.root_module.addSystemIncludePath(b.path("plutovg/plutovg.h"));
	lib.root_module.addSystemIncludePath(b.path("plutosvg/plutosvg.h"));

	b.modules.put("root", lib.root_module) catch {};

	b.installArtifact(lib);
}
