const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	const glfw = b.dependency("zglfw", .{
		.target = target,
		.optimize = optimize,
		.shared = true
	});
	const opengl = b.dependency("zopengl", .{
		.target = target,
		// error: invalid option: -Doptimize
		//.optimize = optimize,
	});

	const build_zig_zon = b.createModule(.{
		.root_source_file = b.path("build.zig.zon"),
		.target = target,
		.optimize = optimize,
	});

	const translate_c = b.addTranslateC(.{
		.root_source_file = b.path("src/c.h"),
		.target = target,
		.optimize = optimize,
	});
	translate_c.linkSystemLibrary("freetype", .{});
	translate_c.linkSystemLibrary("harfbuzz", .{});
	translate_c.linkSystemLibrary("plutosvg", .{});

	const zuil_core = b.createModule(.{
		.root_source_file = b.path("src/core/root.zig"),
		.target = target,
		.optimize = optimize,
		.imports = &.{
			.{
				.name = "c",
				.module = translate_c.createModule(),
			},
		},
	});
	zuil_core.addImport("build.zig.zon", build_zig_zon);

	var lib = b.addLibrary(.{
		.name = "zuil",
		.linkage = .static,
		.root_module = b.addModule("root", .{
			.root_source_file = b.path("src/root.zig"),
			.target = target,
			.optimize = optimize,
		}),
	});
	lib.root_module.addImport("zuilcore", zuil_core);

	lib.root_module.addImport("glfw", glfw.module("root"));
	lib.root_module.linkLibrary(glfw.artifact("glfw"));
	lib.root_module.addImport("opengl", opengl.module("root"));

	b.installArtifact(lib);

	const install_docs = b.addInstallDirectory(.{
		.source_dir = lib.getEmittedDocs(),
		.install_dir = .prefix,
		.install_subdir = "docs",
	});

	const docs_step = b.step("docs", "Install docs into zig-out/docs");
	docs_step.dependOn(&install_docs.step);
}
