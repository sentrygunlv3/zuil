<h1 align="center">
<sub>
<img src="./icon.svg" height="38" width="38">
</sub>
ZUIL
</h1>

---

Zig UI Library

basic ui framework thing made with zig\
using `zglfw` and `zopengl`

---

## example

> test/example project: `test/`\
> run with `./test.sh`

widgets are created using builder functions

```zig
container()
.bounds(400, 225)
.color(colors.RED)
.child(
	container()
	.bounds(20, 20)
	.color(colors.rgb(0, 1.0, 0))
	.build()
)
.build();
```
