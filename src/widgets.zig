//! all the builtin widgets

pub const zcontainer = @import("widgets/container.zig");
pub const container = zcontainer.zContainer;
pub const zlist = @import("widgets/list.zig");
pub const list = zlist.zList;
pub const zicon = @import("widgets/icon.zig");
pub const icon = zicon.zIcon;
pub const zposition = @import("widgets/position.zig");
pub const position = zposition.zPosition;
pub const ztext = @import("widgets/text.zig");
pub const text = ztext.zText;
