//! c ffi for zuil core

const std = @import("std");
const root = @import("root.zig");

const build_zig_zon = @import("build.zig.zon");

export fn zuilCoreVersion() [*c]const u8 {
	return build_zig_zon.version;
}
