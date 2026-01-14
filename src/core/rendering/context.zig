const std = @import("std");
const root = @import("../root.zig");

const shader = root.shader;
const glfw = root.glfw;
const gl = root.gl;

pub const ResourceHandle = struct {
	resource: *Resource,
	context: *RendererContext,

	pub fn init(context: *RendererContext, resource: *Resource) @This() {
		resource.users += 1;
		return .{
			.context = context,
			.resource = resource,
		};
	}

	pub fn deinit(self: *@This()) void {
		self.resource.users -= 1;
		self.context.update();
	}
};

pub const Resource = struct {
	users: u32 = 0,
	type: Type,

	pub const Type = union(enum) {
		texture: u32,
	};

	pub fn init(t: Type) anyerror!*@This() {
		const self = try root.allocator.create(@This());
		self.* = @This(){
			.type = t,
		};
		return self;
	}

	pub fn deinit(self: *@This()) void {
		switch (self.type) {
			.texture => {
				gl.deleteTextures(1, self.type.texture);
			}
		}
		root.allocator.destroy(self);
	}
};

pub const RendererContext = struct {
	resources: std.ArrayList(*Resource) = undefined,
	shaders: std.StringHashMap(u32) = undefined,
	vertex_arrays: u32 = 0,
	buffers: u32 = 0,
	element_buffer: u32 = 0,

	pub fn init() !*@This() {
		const self = try root.allocator.create(@This());

		self.* = @This(){
			.resources = try std.ArrayList(*Resource).initCapacity(root.allocator, 16),
			.shaders = std.StringHashMap(u32).init(root.allocator),
		};

		gl.genVertexArrays(1, &self.vertex_arrays);
		gl.genBuffers(1, &self.buffers);
		gl.genBuffers(1, &self.element_buffer);

		return self;
	}

	pub fn deinit(self: *@This()) void {
		gl.deleteVertexArrays(1, &self.vertex_arrays);
		gl.deleteBuffers(1, &self.buffers);
		gl.deleteBuffers(1, &self.element_buffer);

		self.shaders.deinit();
		self.resources.deinit(root.allocator);

		root.allocator.destroy(self);
	}

	pub fn update(self: *@This()) void {
		for (self.resources.items, 0..) |item, index| {
			std.debug.print("[resource {}] {*} - {d}\n", .{index, item, item.users});
			if (item.users <= 0) {
				const removed = self.resources.swapRemove(index);
				removed.deinit();
			}
		}
	}

	pub fn createTexture(self: *@This(), image: root.ZAsset, width: u32, height: u32) !ResourceHandle {
		std.debug.print("{}x{}\n", .{width, height});
		var bitmap = try root.svg.svgToBitmap(image, width, height);
		defer bitmap.deinit();

		var texture: u32 = 0;

		gl.genTextures(1, &texture);
		gl.activeTexture(gl.TEXTURE0);
		gl.bindTexture(gl.TEXTURE_2D, texture);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
		gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
		gl.texImage2D(
			gl.TEXTURE_2D,
			0,
			gl.RGBA,
			@intCast(bitmap.w),
			@intCast(bitmap.h),
			0,
			gl.BGRA,
			gl.UNSIGNED_BYTE,
			bitmap.data.ptr
		);

		const resource = try Resource.init(.{.texture = texture});
		try self.resources.append(root.allocator, resource);

		return .init(self, resource);
	}
};
