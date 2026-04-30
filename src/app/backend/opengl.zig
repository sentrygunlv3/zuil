const std = @import("std");
const root = @import("../app.zig");

const gl = root.gl;

const ZError = root.ZuilCore.errors.ZError;

var allocator: std.mem.Allocator = undefined;

/// global resource array
var resources: std.ArrayList(*Resource) = undefined;
var resources_to_remove: std.ArrayList(*Resource) = undefined;

var default_mesh: *Resource = undefined;

pub const Resource = struct {
	users: u32 = 0,
	type: Type,

	pub const Type = union(enum) {
		texture: u32,
		shader: struct {
			shader: u32,
			locations: std.StringHashMap(i32) = undefined,

			pub fn getLocation(self: *@This(), name: []const u8) !c_int {
				if (self.locations.get(name)) |r| {
					return @intCast(r);
				} else {
					const loc: i32 = @intCast(gl.getUniformLocation(self.shader, name.ptr));
					try self.locations.put(name, loc);
					return @intCast(loc);
				}
			}
		},
		mesh: struct {
			vertex_arrays: u32 = 0,
			buffers: u32 = 0,
			element_buffer: u32 = 0,
			index_count: u32 = 0,
		},
	};

	pub fn init(t: Type, fake_user: bool) anyerror!*@This() {
		const self = try allocator.create(@This());
		self.* = @This(){
			.type = t,
		};
		switch (self.type) {
			.shader => {
				self.type.shader.locations = .init(allocator);
			},
			else => {}
		}
		if (fake_user) {
			self.users = 1;
		}
		return self;
	}

	pub fn deinit(self: *@This()) void {
		root.context.log(.debug, "deleting: {*} - {s}", .{self, @tagName(self.type)});
		switch (self.type) {
			.texture => {
				gl.deleteTextures(1, self.type.texture);
			},
			.shader => {
				gl.deleteProgram(self.type.shader.shader);
				self.type.shader.locations.deinit();
			},
			.mesh => {
				gl.deleteVertexArrays(1, &self.type.mesh.vertex_arrays);
				gl.deleteBuffers(1, &self.type.mesh.buffers);
				gl.deleteBuffers(1, &self.type.mesh.element_buffer);
			}
		}
		allocator.destroy(self);
	}
};

fn getResource(self: *const root.ZuilCore.context.ResourceHandle) *Resource {
	return @ptrCast(@alignCast(self.resource));
}

fn getResourceFromAny(self: *anyopaque) *Resource {
	return @ptrCast(@alignCast(self));
}

pub const ZRenderFIOpengl = root.ZuilCore.context.ZRenderer{
	.init = init,
	.deinit = deinit,
	.resourceRemoveUser = resourceRemoveUser,
	.resourcesUpdate = resourcesUpdate,
	.clip = clip,
	.clear = clear,
	.renderCommands = renderCommands,
	.createTexture = createTexture,
	.createShader = createShader,
	.createMesh = createMesh,
};

pub fn init(alloc: std.mem.Allocator) anyerror!void {
	allocator = alloc;

	resources = try .initCapacity(allocator, 16);
	resources_to_remove = try .initCapacity(allocator, 16);

	default_mesh = getResource(&try createMesh(&root.ZuilCore.mesh.DefaultMesh));

	root.context.log(.info, "using opengl backend", .{});
}

pub fn deinit() void {
	default_mesh.deinit();
	resources.deinit(allocator);
	resources_to_remove.deinit(allocator);
}

fn resourceRemoveUser(resource: *root.ZuilCore.context.ResourceHandle) anyerror!void {
	const r = getResource(resource);
	r.users -= 1;
	if (r.users <= 0) {
		try resources_to_remove.append(allocator, r);
	}
}

fn resourcesUpdate() void {
	for (resources_to_remove.items) |value| {
		for (resources.items, 0..) |item, i| {
			if (item == value) {
				_ = resources.swapRemove(i);
				item.deinit();
				break;
			}
		}
	}
	resources_to_remove.clearRetainingCapacity();
}

fn getFormatInternal(format: root.ZuilCore.ZBitmap.Format) c_uint {
	return switch (format) {
		.R => gl.R8,
		.RG => gl.RG8,
		.RGB => gl.RGB8,
		.RGBA, .BGRA => gl.RGBA8,
	};
}

fn getFormat(format: root.ZuilCore.ZBitmap.Format) c_uint {
	return switch (format) {
		.R => gl.RED,
		.RG => gl.RG,
		.RGB => gl.RGB,
		.RGBA => gl.RGBA,
		.BGRA => gl.BGRA,
	};
}

fn createTexture(bitmap: *root.ZuilCore.ZBitmap) !root.ZuilCore.context.ResourceHandle {
	var texture: u32 = 0;
	gl.genTextures(1, &texture);
	errdefer gl.deleteTextures(1, texture);
	gl.activeTexture(gl.TEXTURE0);
	gl.bindTexture(gl.TEXTURE_2D, texture);
	gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);
	gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
	gl.texImage2D(
		gl.TEXTURE_2D,
		0,
		getFormatInternal(bitmap.format),
		@intCast(bitmap.w),
		@intCast(bitmap.h),
		0,
		getFormat(bitmap.format),
		gl.UNSIGNED_BYTE,
		bitmap.data.ptr
	);

	const resource = try Resource.init(.{.texture = texture}, true);
	errdefer resource.deinit();
	try resources.append(allocator, resource);

	return .{
		.resource = resource
	};
}

fn createShader(v: []const u8, f: []const u8) !root.ZuilCore.context.ResourceHandle {
	const vertex = try compileShader(gl.VERTEX_SHADER, v);
	const fragment = try compileShader(gl.FRAGMENT_SHADER, f);
	
	const program = gl.createProgram();
	gl.attachShader(program, vertex);
	gl.attachShader(program, fragment);
	gl.linkProgram(program);

	var status: i32 = 0;
	gl.getProgramiv(program, gl.LINK_STATUS, &status);
	if (status == 0) {
		return ZError.FailedToLinkShader;
	}

	gl.deleteShader(vertex);
	gl.deleteShader(fragment);

	const resource = try Resource.init(.{.shader = .{
		.shader = program,
	}}, true);
	errdefer resource.deinit();
	try resources.append(allocator, resource);

	return .{
		.resource = resource
	};
}

fn compileShader(shader_type: u32, source: []const u8) !u32 {
	const s = gl.createShader(shader_type);
	gl.shaderSource(s, 1, @ptrCast(&source), null);
	gl.compileShader(s);
	var status: i32 = 0;
	gl.getShaderiv(s, gl.COMPILE_STATUS, &status);
	if (status == 0) {
		return ZError.FailedToCompileShader;
	}
	return s;
}

fn createMesh(mesh: *const root.ZuilCore.mesh.ZMesh) !root.ZuilCore.context.ResourceHandle {
	var vertex_arrays: u32 = 0;
	var buffers: u32 = 0;
	var element_buffer: u32 = 0;

	gl.genVertexArrays(1, &vertex_arrays);
	gl.genBuffers(1, &buffers);
	gl.genBuffers(1, &element_buffer);
	errdefer gl.deleteVertexArrays(1, vertex_arrays);
	errdefer gl.deleteBuffers(1, buffers);
	errdefer gl.deleteVertexArrays(1, element_buffer);

	gl.bindVertexArray(vertex_arrays);

	gl.bindBuffer(gl.ARRAY_BUFFER, buffers);
	gl.bufferData(gl.ARRAY_BUFFER, @as(isize, @intCast(mesh.vertices.len)) * @sizeOf(f32), mesh.vertices.ptr, gl.STATIC_DRAW);

	gl.bindBuffer(gl.ELEMENT_ARRAY_BUFFER, element_buffer);
	gl.bufferData(gl.ELEMENT_ARRAY_BUFFER, @as(isize, @intCast(mesh.indices.len)) * @sizeOf(u32), mesh.indices.ptr, gl.STATIC_DRAW);

	gl.vertexAttribPointer(0, 2, gl.FLOAT, gl.FALSE, 4 * @sizeOf(f32), null);
	gl.enableVertexAttribArray(0);

	gl.vertexAttribPointer(2, 2, root.gl.FLOAT, root.gl.FALSE, 4 * @sizeOf(f32), @ptrFromInt(2 * @sizeOf(f32)));
	gl.enableVertexAttribArray(2);

	gl.bindVertexArray(0);

	const resource = try Resource.init(
		.{.mesh = .{
			.vertex_arrays = vertex_arrays,
			.buffers = buffers,
			.element_buffer = element_buffer,
			.index_count = @intCast(mesh.indices.len),
		}},
		true
	);
	errdefer resource.deinit();
	try resources.append(allocator, resource);

	return .{
		.resource = resource
	};
}

fn clip(area: ?root.ZuilCore.types.ZBounds) void {
	if (area) |a| {
		gl.enable(gl.SCISSOR_TEST);
		gl.scissor(
			@intFromFloat(@floor(a.x)),
			@intFromFloat(@floor(a.y)),
			@intFromFloat(@floor(a.w)),
			@intFromFloat(@floor(a.h))
		);
	} else {
		gl.disable(gl.SCISSOR_TEST);
	}
}

fn clear(color: root.ZuilCore.color.ZColor) void {
	const clear_color = [_]f32{color.r, color.g, color.b, color.a};
	root.gl.clearBufferfv(root.gl.COLOR, 0, &clear_color);
}

fn renderCommands(commands: *root.ZuilCore.context.RenderCommandList) anyerror!void {
	//gl.polygonMode(gl.FRONT_AND_BACK, gl.LINE);
	var current: u32 = 0;

	for (commands.commands.items) |command| {
		var mesh_resource: *Resource = default_mesh;
		if (command.mesh) |mesh| {
			mesh_resource = getResource(&mesh);
		}

		gl.bindVertexArray(mesh_resource.type.mesh.vertex_arrays);
		const index_count = mesh_resource.type.mesh.index_count;

		const resource = getResource(&command.shader);
		if (resource.type.shader.shader != current) {
			gl.useProgram(resource.type.shader.shader);
			current = resource.type.shader.shader;
		}

		for (command.parameters) |value| {
			switch (value.value) {
				.uniform1f => {
					gl.uniform1f(
						try resource.type.shader.getLocation(value.name),
						value.value.uniform1f
					);
				},
				.uniform2f => {
					gl.uniform2f(
						try resource.type.shader.getLocation(value.name),
						value.value.uniform2f.a,
						value.value.uniform2f.b
					);
				},
				.uniform3f => {
					gl.uniform3f(
						try resource.type.shader.getLocation(value.name),
						value.value.uniform3f.a,
						value.value.uniform3f.b,
						value.value.uniform3f.c
					);
				},
				.uniform4f => {
					gl.uniform4f(
						try resource.type.shader.getLocation(value.name),
						value.value.uniform4f.a,
						value.value.uniform4f.b,
						value.value.uniform4f.c,
						value.value.uniform4f.d
					);
				},
				.uniform1i => {
					gl.uniform1i(
						try resource.type.shader.getLocation(value.name),
						value.value.uniform1i
					);
				},
				.uniform2i => {
					gl.uniform2i(
						try resource.type.shader.getLocation(value.name),
						value.value.uniform2i.a,
						value.value.uniform2i.b
					);
				},
				.uniform3i => {
					gl.uniform3i(
						try resource.type.shader.getLocation(value.name),
						value.value.uniform3i.a,
						value.value.uniform3i.b,
						value.value.uniform3i.c,
					);
				},
				.uniform4i => {
					gl.uniform4i(
						try resource.type.shader.getLocation(value.name),
						value.value.uniform4i.a,
						value.value.uniform4i.b,
						value.value.uniform4i.c,
						value.value.uniform4i.d
					);
				},
			}
		}

		for (command.textures) |value| {
			const tex = getResourceFromAny(value.texture.resource);
			if (tex.type != .texture) {
				continue;
			}

			const slot: c_uint = switch (value.slot) {
				0 => gl.TEXTURE0,
				1 => gl.TEXTURE1,
				2 => gl.TEXTURE2,
				else => continue
			};
			gl.activeTexture(slot);
			gl.bindTexture(gl.TEXTURE_2D, tex.type.texture);
		}

		gl.drawElements(gl.TRIANGLES, @intCast(index_count), gl.UNSIGNED_INT, null);
	}
}
