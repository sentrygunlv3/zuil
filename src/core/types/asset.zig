pub const ZAsset = struct {
	data: Data,
	type: Type,

	pub const Data = union(enum) {
		compile_time: struct {
			ptr: [*]const u8,
			len: usize,
		},
		runtime: *const []const u8,
	};

	pub const Type = enum {
		other,
		svg,
		ttf,
	};
};
