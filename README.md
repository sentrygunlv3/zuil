<h1 align="center">
<sub>
<img src="./icon.svg" height="36" width="36">
</sub>
ZUIL
</h1>

> [!CAUTION]
> WIP

> [!IMPORTANT]
> NOT TESTED ON WINDOWS\
> the `build.zig` links some libraries as system libraries\
> which i assume doesnt work on windows

---

ZUIL (Zig UI Library)

retained mode gui framework written in zig

using `zglfw`, `zopengl`, `plutosvg`, `harfbuzz` and `freetype` libs

---

<img src="./screenshot.png">

### core/default widget features

- asset/file registry
- resource system
- input system (keyboard and mouse only)
- rendering abstraction (shaders are written in GLSL)
- text rendering (WIP)

## examples

### widgets

widgets are created using builder functions

```zig
// .c for common builder functions
widgets.container()
.c.size(.{.dp = 1200}, .{.percentage = 1})
.color(colors.WHITE)
.child(
	widgets.list()
	.c.size(.fill, .fill) // fill is same as .{.percentage = 1}
	.direction(.vertical)
	.spacing(1)
	.children(.{
		widgets.icon()
		.c.size(.{.dp = 200}, .{.dp = 200})
		.c.keepSizeRatio(true)
		.icon("icon.svg")
		.build(),
		widgets.container()
		.c.size(.{.dp = 50}, .{.dp = 30})
		.c.eventCallback(containerClick) // fn (*ZWidget, *const ZEvent) callconv(.c) c_int
		.color(colors.rgb(0, 1.0, 0.5))
		.build(),
		widgets.container()
		.c.size(.{.pixel = 50}, .{.dp = 30})
		.build(),
		widgets.container()
		.c.size(.{.mm = 50}, .{.dp = 30})
		.build(),
		widgets.container()
		.c.size(.{.percentage = 0.5}, .{.dp = 30})
		.build(),
	})
	.build()
)
.build();
```

### test project

the test project is in the `test` directory\
run with `./test.sh` or `./test.sh -Ddebug`
or build manually

keybinds:

- `space`: change the layout
- `F1`: spawn a new window (currently broken see comment in render function inside src/app/window.zig)

## project structure

files/modules in `src` dir:

- `core` directory has the base widget system
- `app` directory has glfw specific things and can be used to create windows that use the core widget system
- `shaders`/`shaders.zig` and `widgets`/`widgets.zig` directories/files have the default widgets/shaders
- `root.zig` is basically the lib root for the `app` module
