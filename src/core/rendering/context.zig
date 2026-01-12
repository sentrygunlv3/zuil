const std = @import("std");
const root = @import("../root.zig");

const shader = root.shader;
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
				root.gl.deleteTextures(1, self.type.texture);
			}
		}
		root.allocator.destroy(self);
	}
};

pub const RendererContext = struct {
	resources: std.ArrayList(*Resource) = undefined,

	pub fn init() !@This() {
		return .{
			.resources = try std.ArrayList(*Resource).initCapacity(root.allocator, 16),
		};
	}

	pub fn deinit(self: *@This()) void {
		self.resources.deinit(root.allocator);
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

		root.gl.genTextures(1, &texture);
		root.gl.activeTexture(root.gl.TEXTURE0);
		root.gl.bindTexture(root.gl.TEXTURE_2D, texture);
		root.gl.texParameteri(root.gl.TEXTURE_2D, root.gl.TEXTURE_MIN_FILTER, root.gl.NEAREST);
		root.gl.texParameteri(root.gl.TEXTURE_2D, root.gl.TEXTURE_MAG_FILTER, root.gl.NEAREST);
		root.gl.texImage2D(
			root.gl.TEXTURE_2D,
			0,
			root.gl.RGBA,
			@intCast(bitmap.w),
			@intCast(bitmap.h),
			0,
			root.gl.BGRA,
			root.gl.UNSIGNED_BYTE,
			bitmap.data.ptr
		);

		const resource = try Resource.init(.{.texture = texture});
		try self.resources.append(root.allocator, resource);

		return .init(self, resource);
	}
};
