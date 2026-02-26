const std = @import("std");
const TagType = @import("tag.zig").TagType;
const meta_util = @import("util.zig");
pub const Error = std.mem.Allocator.Error || std.Io.Writer.Error || error{CastError};

/// Serializes `val` as an NBT root compound into `w`.
///
/// This function writes:
/// 1. A `.Compound` tag type.
/// 2. An optional empty root name (if `write_name` is `true`).
/// 3. The encoded contents of `val`.
///
/// The root value is always encoded as a compound, matching the
/// standard NBT file format convention.
///
/// Type requirements:
/// - `val` must be representable as an NBT compound.
/// - Structs are encoded as compounds.
/// - Types may provide a custom `writeNbt(Self)` method to override
///   the default encoding logic.
///
/// Errors:
/// - Propagates writer errors.
/// - Returns `error.CastError` if integer narrowing fails.
/// - May emit compile errors for unsupported types.
///
/// This is the main entry point for writing strongly-typed Zig values
/// into NBT format.
pub fn write(w: *std.Io.Writer, val: anytype, write_name: bool) !void {
    const writer: Self = .{ .writer = w };
    try writer.writeTagType(TagType.Compound);
    if (write_name) try writer.writeString("");
    try writer.innerWrite(val);
}

writer: *std.Io.Writer,

const Self = @This();

pub fn writeByteAs(self: Self, val: anytype) !void {
    switch (@typeInfo(@TypeOf(val))) {
        .bool => try self.writeByte(@intFromBool(val)),
        .int => try self.writeByte(meta_util.castInt(val, i8)),
        else => @compileError("can't write " ++ @typeName(@TypeOf(val)) ++ " as byte"),
    }
}

pub fn writeTagType(self: Self, val: TagType) !void {
    try self.writer.writeByte(@intFromEnum(val));
}

pub fn writeByte(self: Self, val: i8) !void {
    try self.writer.writeInt(i8, val, .big);
}
pub fn writeShort(self: Self, val: i16) !void {
    try self.writer.writeInt(i16, val, .big);
}
pub fn writeInt(self: Self, val: i32) !void {
    try self.writer.writeInt(i32, val, .big);
}
pub fn writeLong(self: Self, val: i64) !void {
    try self.writer.writeInt(i64, val, .big);
}

pub fn writeFloat(self: Self, val: f32) !void {
    try self.writeInt(@bitCast(val));
}
pub fn writeDouble(self: Self, val: f64) !void {
    try self.writeDouble(@bitCast(val));
}

pub fn writeString(self: Self, val: []const u8) !void {
    try self.writeShort(@intCast(val.len));
    try self.writer.writeAll(val);
}

pub fn writeLen(self: Self, len: u31) !void {
    try self.writeInt(len);
}

/// Recursively encodes `val` into NBT format.
///
/// This is the core serialization routine used by `write`.
/// It inspects `@typeInfo(@TypeOf(val))` and emits the corresponding
/// binary representation.
///
/// Supported mappings:
/// - `bool`              → `.Byte` (0 or 1)
/// - integers            → `.Byte`, `.Short`, `.Int`, `.Long` (size-based)
/// - `f32` / `f64`       → `.Float` / `.Double`
/// - `[]const u8`        → `.String`
/// - slices/arrays/vectors:
///     * `u8/i8`  → `.ByteArray`
///     * `i32/u32`→ `.IntArray`
///     * `i64/u64`→ `.LongArray`
///     * otherwise→ `.List`
/// - structs             → `.Compound`
///     * Fields equal to their default values are omitted.
///     * Optional fields are omitted when `null`.
///     * A field named `"trailing\n"` is treated as a dynamic
///       string-keyed map and written last.
/// - enums               → encoded as their underlying integer type
///
/// Customization:
/// - If the type defines `writeNbt(Self)`, that method is used.
/// - String-keyed hash maps detected via `meta_util.stringHashMapType`
///   are serialized as compounds with dynamic keys.
///
/// Structural behavior:
/// - Compounds end with a `.End` tag.
/// - Lists write their element tag type and length before elements.
/// - Empty lists write `.End` as their element tag.
///
/// Errors:
/// - Propagates writer errors.
/// - Returns `error.CastError` if numeric narrowing fails.
/// - Produces compile errors for unsupported types.
///
/// This function is not intended to be called directly unless
/// implementing custom NBT writing behavior.
pub fn innerWrite(w: Self, val: anytype) Error!void {
    const T = @TypeOf(val);
    switch (@typeInfo(T)) {
        .void => return {},
        .bool => {
            try w.writeByte(if (val) 1 else 0);
        },
        .int => |int| {
            if (int.bits <= 8)
                try w.writeByte(try meta_util.castInt(val, i8))
            else if (int.bits <= 16)
                try w.writeShort(try meta_util.castInt(val, i16))
            else if (int.bits <= 32)
                try w.writeInt(try meta_util.castInt(val, i32))
            else if (int.bits <= 64)
                try w.writeLong(try meta_util.castInt(val, i64))
            else
                @compileError("ambiguous type " ++ @typeName(T));
        },
        .float => |float| {
            if (float.bits == 32)
                try w.writeFloat(val)
            else if (float.bits == 64)
                try w.writeDouble(val)
            else
                @compileError("unsupported float type " ++ @typeName(T));
        },
        .pointer => |pointer| {
            if (std.meta.hasMethod(T, "writeNbt")) {
                return try val.writeNbt(w);
            }
            switch (pointer.size) {
                .slice => {
                    if (T == []const u8) try w.writeString(val) else {
                        if (val.len == 0)
                            try w.writeTagType(.End)
                        else if (TagType.fromVal(val).? == .List)
                            try w.writeTagType(TagType.fromVal(val[0]).?);
                        try w.writeLen(@intCast(val.len));
                        for (val) |v| try innerWrite(w, v);
                    }
                },
                .one => try innerWrite(w, val.*),
                else => @compileError("pointers are not supported"),
            }
        },
        inline .array, .vector => |_| {
            try w.writeLen(@intCast(val.len));
            if (val.len == 0)
                try w.writeTagType(.End)
            else if (TagType.fromVal(val).? == .List)
                try w.writeTagType(TagType.fromVal(val[0]).?);
            for (val) |v| try innerWrite(w, v);
        },
        .@"struct" => |s| {
            if (std.meta.hasMethod(T, "writeNbt")) {
                // switch (@typeInfo(@typeInfo(@TypeOf(T.writeNbt)).@"fn".params[0].type.?)) {
                //     .pointer =>val.
                // }
                return try val.writeNbt(w);
            }
            if (s.is_tuple) @compileError("tuple structs are not supported");
            if (s.backing_integer) |int| {
                try innerWrite(@as(int, @bitCast(val)));
                return;
            }
            if (meta_util.stringHashMapType(T)) |_| {
                var it = val.iterator();
                while (it.next()) |item| {
                    try w.writeTagType(TagType.fromVal(item.value_ptr).?);
                    try w.writeString(item.key_ptr.*);
                    try innerWrite(w, item.value_ptr.*);
                }
                try w.writeTagType(.End);
                return;
            }

            inline for (s.fields) |field| {
                const curr = @field(val, field.name);
                comptime var opt = false;
                switch (@typeInfo(field.type)) {
                    .optional => opt = true,
                    .void => continue,
                    else => {},
                }
                if ((!opt or curr != null) and (field.defaultValue() == null or !std.meta.eql(field.defaultValue().?, curr))) {
                    const v = if (opt) curr.? else curr;
                    if (comptime !std.mem.eql(u8, field.name, "trailing\n")) {
                        try w.writeTagType(TagType.fromVal(v).?);
                        try w.writeString(field.name);
                        try innerWrite(w, v);
                    }
                }
            }

            inline for (s.fields) |field| if (comptime std.mem.eql(u8, field.name, "trailing\n"))
                return try innerWrite(w, val.@"trailing\n");
            try w.writeTagType(.End);
        },
        .optional => @compileError("optional not supported here"),
        .@"enum" => |e| {
            const v: e.tag_type = @intFromEnum(val);
            try innerWrite(w, v);
        },
        .@"union" => {
            if (std.meta.hasMethod(T, "writeNbt")) {
                // switch (@typeInfo(@typeInfo(@TypeOf(T.writeNbt)).@"fn".params[0].type.?)) {
                //     .pointer =>val.
                // }
                return try val.writeNbt(w);
            }
            @compileError("TODO: " ++ @typeName(T));
        },
        else => @compileError("unsupported type " ++ @typeName(T)),
    }
}
