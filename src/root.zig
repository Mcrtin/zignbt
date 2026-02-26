pub const NbtReader = @import("Reader.zig");
pub const readLeaky = NbtReader.readLeaky;

pub const NbtWriter = @import("Writer.zig");
pub const write = NbtWriter.write;

pub const TagType = @import("tag.zig").TagType;

const types = @import("types.zig");
pub const NbtValue = types.Value;
pub const BoundedArray = types.BoundedArray;
