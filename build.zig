const std = @import("std");

pub fn build(b: *std.Build) void {
	const target = b.standardTargetOptions(.{});
	const optimize = b.standardOptimizeOption(.{});

	// core

	var zuil_core = b.addLibrary(.{
		.name = "zuil_core",
		.linkage = .static,
		.root_module = b.addModule("root", .{
			.root_source_file = b.path("src/core/root.zig"),
			.target = target,
			.optimize = optimize,
		}),
	});

	b.installArtifact(zuil_core);

	// widgets

	const translate_c = b.addTranslateC(.{
		.root_source_file = b.path("src/widgets/c.h"),
		.target = target,
		.optimize = optimize,
	});
	translate_c.linkSystemLibrary("freetype", .{});
	translate_c.linkSystemLibrary("harfbuzz", .{});
	translate_c.linkSystemLibrary("plutosvg", .{});

	var zuil_widgets = b.addLibrary(.{
		.name = "zuil_widgets",
		.linkage = .static,
		.root_module = b.addModule("root", .{
			.root_source_file = b.path("src/widgets/root.zig"),
			.target = target,
			.optimize = optimize,
			.imports = &.{
				.{
					.name = "zuilcore",
					.module = zuil_core.root_module,
				},
				.{
					.name = "c",
					.module = translate_c.createModule(),
				},
			}
		}),
	});

	b.installArtifact(zuil_widgets);

	// app

	const opengl = b.dependency("zopengl", .{
		.target = target,
		// error: invalid option: -Doptimize
		//.optimize = optimize,
	});

	const app_translate_c = b.addTranslateC(.{
		.root_source_file = b.path("src/app/c.h"),
		.target = target,
		.optimize = optimize,
	});
	app_translate_c.linkSystemLibrary("sdl3", .{});

	var zuil_app = b.addLibrary(.{
		.name = "zuil",
		.linkage = .static,
		.root_module = b.addModule("root", .{
			.root_source_file = b.path("src/app/root.zig"),
			.target = target,
			.optimize = optimize,
			.imports = &.{
				.{
					.name = "zuilcore",
					.module = zuil_core.root_module,
				},
				.{
					.name = "c",
					.module = app_translate_c.createModule(),
				},
			}
		}),
	});
	zuil_app.root_module.addCSourceFile(.{.file = b.path("src/app/c.c")});
	zuil_app.root_module.addImport("zuilcore", zuil_core.root_module);
	zuil_app.root_module.addImport("widgets", zuil_widgets.root_module);
	zuil_app.root_module.addImport("opengl", opengl.module("root"));

	b.installArtifact(zuil_app);

	// ---

	const zuil_core_docs = b.addInstallDirectory(.{
		.source_dir = zuil_core.getEmittedDocs(),
		.install_dir = .prefix,
		.install_subdir = "docs",
	});

	const zuil_widgets_docs = b.addInstallDirectory(.{
		.source_dir = zuil_widgets.getEmittedDocs(),
		.install_dir = .prefix,
		.install_subdir = "docs",
	});

	const zuil_app_docs = b.addInstallDirectory(.{
		.source_dir = zuil_app.getEmittedDocs(),
		.install_dir = .prefix,
		.install_subdir = "docs",
	});

	const docs_step = b.step("docs", "Install docs into zig-out/docs");
	docs_step.dependOn(&zuil_core_docs.step);
	docs_step.dependOn(&zuil_widgets_docs.step);
	docs_step.dependOn(&zuil_app_docs.step);
}
