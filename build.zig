const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const build_options = b.addOptions();
	build_options.addOption(bool, "debug", b.option(bool, "debug", "enable debug") orelse false);

	const glfw = b.dependency("zglfw", .{});
	const opengl = b.dependency("zopengl", .{});

	const build_zig_zon = b.createModule(.{
		.root_source_file = b.path("build.zig.zon"),
		.target = target,
		.optimize = optimize,
	});

	var lib = b.addLibrary(.{
		.name = "zuil",
		.linkage = .static,
		.root_module = b.addModule("root", .{
			.root_source_file = b.path("src/root.zig"),
			.target = target,
			.optimize = optimize,
		}),
	});
	lib.root_module.addImport("build.zig.zon", build_zig_zon);

	lib.root_module.addOptions("build_options", build_options);
	//lib.root_module.addSystemIncludePath(b.path("include"));

	lib.root_module.addImport("glfw", glfw.module("root"));
	lib.root_module.linkLibrary(glfw.artifact("glfw"));
	lib.root_module.addImport("opengl", opengl.module("root"));

	lib.root_module.linkSystemLibrary("freetype", .{});
	lib.root_module.linkSystemLibrary("plutosvg", .{});

	b.installArtifact(lib);

	const install_docs = b.addInstallDirectory(.{
		.source_dir = lib.getEmittedDocs(),
		.install_dir = .prefix,
		.install_subdir = "docs",
	});

	const docs_step = b.step("docs", "Install docs into zig-out/docs");
	docs_step.dependOn(&install_docs.step);
}
