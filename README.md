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

basic ui framework made with zig\
using `zglfw`, `zopengl`, `plutosvg`/`plutovg`, `harfbuzz` and `freetype`

---

<img src="./screenshot.png">

### features

- modular widget system
- asset/file registry
- icon/texture rendering with a resource system
- input system (keyboard and mouse only)
- rendering abstraction (only core and shaders are written for opengl)
- text rendering (WIP)

### missing features/todo

- more optimized rendering
- and more

## examples

### widgets

widgets are created using builder functions (the functions will probably change in the future)

```zig
// .c for common builder functions
widgets.container()
.c.size(.{.dp = 1200}, .{.percentage = 1})
.color(colors.WHITE)
.child(
	widgets.list()
	.c.size(.fill(), .fill()) // fill is same as .{.percentage = 1}
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

### example/test project

the test/example project is in the `test` directory\
build and run with `./test.sh` or `./test.sh -Ddebug`
or build manually

keybinds:

- `space`: change the layout
- `F1`: spawn a new window

(the blue widget under the icon widget is clickable)

## project structure

the `include` directory has headers for `plutosvg`/`plutovg` instead of using the system installed headers mainly to stop zls from giving false errors

files/modules in `src` dir:

- `core` directory has the base widget system
- `app` directory has glfw specific things and can be used to create windows that use the core widget system
- `shaders`/`shaders.zig` and `widgets`/`widgets.zig` directories/files have the default widgets/shaders
- `root.zig` is basically the lib root for the `app` module

## technical info

window processing logic overview

1. process input from queue
   1. send to global input handler
   2. if input was let through
      - send keyboard input to focused widget
      - send mouse input to hovered widget
2. if the windows layout is marked dirty check
   - if root widgets layout is dirty then recalculate the whole tree
   - if root widget is not dirty go down a step with no recalculation
     - if a child widget is dirty recalculate layout from that widget down
     - else continue going down
3. if the windows render is marked dirty
   - if entire is dirty
     - render entire widget tree
   - if only a part is dirty
     - render only that area
