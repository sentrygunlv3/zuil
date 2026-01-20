const std = @import("std");
const root = @import("../root.zig");

pub const context = @import("context.zig");

const shader = root.shader;
const gl = root.gl;

pub const ZRenderFIOpengl = @import("backend/opengl.zig");

pub const ZRenderFI = struct {
	init: *const fn () anyerror!void = undefined,
	deinit: *const fn () void = undefined,
	resourceRemoveUser: ?*const fn (resource: *context.ResourceHandle) anyerror!void = null,
	resourcesUpdate: ?*const fn () void = null,
	clip: ?*const fn (area: ?root.types.ZBounds) void = null,
	clear: ?*const fn (color: root.color.ZColor) void = null,
	renderCommands: ?*const fn (c: *context.RenderContext, commands: *context.RenderCommandList) anyerror!void = null,
	createTexture: ?*const fn (image: root.ZAsset, width: u32, height: u32) anyerror!context.ResourceHandle = null,
	createShader: ?*const fn (v: []const u8, f: []const u8) anyerror!context.ResourceHandle = null,
};

pub fn init() anyerror!void {
	try root.render_fi.init();
}

pub fn deinit() void {
	root.render_fi.deinit();
}

pub fn resourceRemoveUser(resource: *context.ResourceHandle) anyerror!void {
	if (root.render_fi.resourceRemoveUser) |func| {
		try func(resource);
		return;
	}
	return root.ZError.NotSupportedByBackend;
}

pub fn resourcesUpdate() anyerror!void {
	if (root.render_fi.resourcesUpdate) |func| {
		func();
		return;
	}
	return root.ZError.NotSupportedByBackend;
}

pub fn clip(area: ?root.types.ZBounds) !void {
	if (root.render_fi.clip) |func| {
		func(area);
		return;
	}
	return root.ZError.NotSupportedByBackend;
}

pub fn clear(color: root.color.ZColor) !void {
	if (root.render_fi.clear) |func| {
		func(color);
		return;
	}
	return root.ZError.NotSupportedByBackend;
}

pub fn renderCommands(c: *context.RenderContext, commands: *context.RenderCommandList) anyerror!void {
	if (root.render_fi.renderCommands) |func| {
		try func(c, commands);
		return;
	}
	return root.ZError.NotSupportedByBackend;
}

pub fn createTexture(image: root.ZAsset, width: u32, height: u32) anyerror!context.ResourceHandle {
	if (root.render_fi.createTexture) |func| {
		return try func(image, width, height);
	}
	return root.ZError.NotSupportedByBackend;
}

pub fn createShader(v: []const u8, f: []const u8) !context.ResourceHandle {
	if (root.render_fi.createShader) |func| {
		return try func(v, f);
	}
	return root.ZError.NotSupportedByBackend;
}
