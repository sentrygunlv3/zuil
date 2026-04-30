//! the root of zuil core

const std = @import("std");

pub const c = @import("c");

pub const cffi = @import("c.zig");

pub const color = @import("types/color.zig");
pub const input = @import("types/input.zig");
pub const types = @import("types/generic.zig");
pub const widget = @import("widget/base.zig");
pub const assets = @import("assets/asset_registry.zig");
pub const context = @import("context.zig");
pub const svg = @import("assets/helpers/svg.zig");
pub const font = @import("assets/helpers/font.zig");
pub const tree = @import("tree.zig");
pub const errors = @import("types/error.zig");
pub const mesh = @import("types/mesh.zig");

pub const ZError = errors.ZError;
pub const ZBitmap = @import("types/bitmap.zig").ZBitmap;
pub const ZAsset = @import("types/asset.zig").ZAsset;
pub const ZContext = context.ZContext;
