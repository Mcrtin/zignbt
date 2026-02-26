const std = @import("std");
const TagType = @import("tag.zig").TagType;
const meta_util = @import("util.zig");
pub const Error = std.mem.Allocator.Error || std.Io.Reader.TakeEnumError || error{ CastError, WrongTag, MissingField, WrongFormat, SizeError, DuplicateField };

/// Parses an NBT payload from `r` into a value of type `T`.
///
/// This function expects the stream to begin with a `.Compound` tag.
/// If `read_name` is `true`, the root compound must have an empty name,
/// otherwise `error.WrongFormat` is returned.
///
/// Memory behavior:
/// - Any dynamically allocated memory (strings, slices, maps, etc.)
///   is allocated using `alloc`.
/// - The function is "leaky" in the sense that it does not perform any
///   cleanup on partial failure — the caller is responsible for freeing
///   all successfully allocated memory reachable from the returned value.
///
/// Type requirements:
/// - `T` must be representable from an NBT `.Compound`.
/// - Structs are decoded from compound tags.
/// - Slices, maps, and nested containers require a non-null allocator.
///
/// Errors:
/// - Returns `error.WrongTag`, `error.WrongFormat`, `error.MissingField`,
///   `error.DuplicateField`, `error.SizeError`, `error.CastError`,
///   allocator errors, or reader errors.
/// - Propagates any I/O failures from `r`.
///
/// This is the main entry point for decoding strongly-typed values from NBT.
pub fn readLeaky(r: *std.Io.Reader, T: type, read_name: bool, alloc: std.mem.Allocator) !T {
    const reader: Self = .{ .reader = r };
    try (try reader.takeTagType()).expect(.Compound);
    if (read_name and (try reader.takeString()).len != 0) return error.WrongFormat;
    return innerParse(reader, T, .Compound, alloc);
}

reader: *std.Io.Reader,

const Self = @This();

pub fn takeChildTag(self: Self, tag: TagType) !?TagType {
    return switch (tag) {
        .List => try self.takeTagType(),
        .IntArray => .Int,
        .LongArray => .Long,
        .ByteArray => .Byte,
        else => null,
    };
}
pub fn takeTagType(self: Self) !TagType {
    return self.reader.takeEnum(TagType, .big);
}
pub fn takeByte(self: Self) !i8 {
    return self.reader.takeInt(i8, .big);
}
pub fn takeShort(self: Self) !i16 {
    return self.reader.takeInt(i16, .big);
}
pub fn takeInt(self: Self) !i32 {
    return self.reader.takeInt(i32, .big);
}
pub fn takeLong(self: Self) !i64 {
    return self.reader.takeInt(i64, .big);
}

pub fn takeFloat(self: Self) !f32 {
    return @bitCast(try self.takeInt());
}

pub fn takeDouble(self: Self) !f64 {
    return @bitCast(try self.takeLong());
}

pub fn takeString(self: Self) ![]const u8 {
    return self.reader.take(try meta_util.castInt(try self.takeShort(), u15));
}

pub fn takeLen(self: Self) !u31 {
    return meta_util.castInt(try self.takeInt(), u31);
}

/// Recursively parses a value of type `T` from the NBT stream,
/// assuming the current tag type is `tag`.
///
/// This is the core decoding routine used by `readLeaky`.
/// It dispatches on `@typeInfo(T)` and enforces that the provided
/// NBT `tag` matches the expected representation.
///
/// Supported mappings:
/// - `bool`              ← `.Byte` (0 or 1)
/// - integers            ← `.Byte`, `.Short`, `.Int`, `.Long` (size-based)
/// - `f32` / `f64`       ← `.Float` / `.Double`
/// - `[]const u8`        ← `.String` (copied using `alloc`)
/// - slices              ← `.List`, `.ByteArray`, `.IntArray`, `.LongArray`
/// - fixed arrays        ← list-like tags with exact length match
/// - structs             ← `.Compound`
///     * Fields are matched by name.
///     * Duplicate fields cause `error.DuplicateField`.
///     * Missing required fields cause `error.MissingField`.
///     * Default field values are filled via `std.json.fillDefaultStructValues`.
///     * A field named `"trailing\n"` may capture unknown keys into a
///       string-keyed hashmap.
/// - enums               ← underlying integer tag type
/// - optionals           ← parsed as their child type (no explicit null tag)
///
/// Special cases:
/// - If `T` defines `pub fn readNbt(...)`, that function is used instead.
/// - If `T` matches a `std.StringHashMapUnmanaged(V)`-like type (also supports `std.StringArrayHashMapUnmanaged(V)`), it is decoded from a compound
///   with string keys and values of type `V`.
///
/// Allocation:
/// - Dynamic containers require `alloc` to be non-null.
/// - The allocator is forwarded recursively.
///
/// Errors:
/// - `error.WrongTag` if the NBT tag does not match the expected shape.
/// - `error.SizeError` for fixed-size container mismatches.
/// - `error.CastError` for invalid numeric or boolean conversions.
/// - `error.MissingField` / `error.DuplicateField` for struct decoding.
/// - Any allocator or reader errors are propagated.
///
/// This function is not intended to be called directly unless
/// implementing custom decoding behavior.
pub fn innerParse(self: Self, T: type, tag: TagType, alloc: ?std.mem.Allocator) Error!T {
    switch (@typeInfo(T)) {
        .void => return {},
        .bool => {
            try tag.expect(.Byte);
            const b = try self.takeByte();
            return if (b == 1) true else if (b == 0) false else error.CastError;
        },
        .int => |int| {
            if (int.bits <= 8) {
                try tag.expect(.Byte);
                return meta_util.castInt(try self.takeByte(), T);
            } else if (int.bits <= 16) {
                try tag.expect(.Short);
                return meta_util.castInt(try self.takeShort(), T);
            } else if (int.bits <= 32) {
                try tag.expect(.Int);
                return meta_util.castInt(try self.takeInt(), T);
            } else if (int.bits <= 64) {
                try tag.expect(.Long);
                return meta_util.castInt(try self.takeLong(), T);
            } else @compileError("ambiguous type " ++ @typeName(T));
        },
        .float => |float| {
            if (float.bits == 32) {
                try tag.expect(.Float);
                return self.takeFloat();
            } else if (float.bits == 64) {
                try tag.expect(.Double);
                return self.takeDouble();
            } else @compileError("unsupported float type " ++ @typeName(T));
        },
        .pointer => |pointer| {
            if (pointer.size != .slice) @compileError("unsupported ptr type " ++ @typeName(T));
            if (pointer.child == u8 and pointer.is_const) {
                try tag.expect(.String);
                return alloc.?.dupe(u8, try self.takeString());
            }
            if (try self.takeChildTag(tag)) |child| {
                // r.reader.readSliceEndianAlloc(alloc.?, pointer.child, r.takeLen(), .big);
                const res: []pointer.child = try alloc.?.alloc(pointer.child, try self.takeLen());
                for (res) |*re|
                    re.* = try innerParse(self, pointer.child, child, alloc);
                return res;
            } else return error.WrongTag;
        },
        .array => |arr| {
            //TODO str
            if (try self.takeChildTag(tag)) |child| {
                if (try self.takeLen() != arr.len) return error.SizeError;
                var res: [arr.len]arr.child = undefined;
                for (&res) |*re|
                    re.* = try innerParse(self, arr.child, child, alloc);
                return res;
            } else return error.WrongTag;
        },
        .@"struct" => |s| {
            if (std.meta.hasFn(T, "readNbt")) {
                return T.readNbt(alloc, self, tag);
            }
            if (meta_util.stringHashMapType(T)) |inner| {
                var res: T = .empty;
                try tag.expect(.Compound);
                var curr = try self.takeTagType();
                while (curr != .End) {
                    try res.put(alloc.?, try self.takeString(), try innerParse(self, inner, curr, alloc));
                    curr = try self.takeTagType();
                }
                return res;
            }
            var res: T = undefined;
            if (s.is_tuple) {
                if (try self.takeChildTag(tag)) |child| {
                    if (try self.takeLen() != s.fields) return error.SizeError;
                    inline for (res.fields, 0..) |item, i| {
                        res[i] = try innerParse(self, item.type, child, alloc);
                    }
                } else return error.WrongTag;
            }
            if (s.backing_integer) |int| return @bitCast(try innerParse(self, int, tag, alloc)) else {
                try tag.expect(.Compound);
                var fields_seen = [_]bool{false} ** s.fields.len;
                var curr = try self.takeTagType();
                const inner: ?type = blk: inline for (s.fields, 0..) |field, i| {
                    if (comptime std.mem.eql(u8, field.name, "trailing\n")) {
                        if (meta_util.stringHashMapType(field.type)) |inn| {
                            res.@"trailing\n" = .empty;
                            fields_seen[i] = true;
                            break :blk inn;
                        } else @compileError("trailing\\n field has to be a Hashmap not " ++ @typeName(field.type) ++ field.name);
                    }
                } else null;

                while (curr != .End) {
                    const name = try self.takeString();
                    inline for (s.fields, 0..) |field, i| {
                        if (std.mem.eql(u8, name, field.name)) {
                            if (fields_seen[i]) return error.DuplicateField;
                            fields_seen[i] = true;
                            @field(res, field.name) = try innerParse(self, field.type, curr, alloc);
                            break;
                        }
                    } else if (inner) |inn| try res.@"trailing\n".put(alloc.?, name, try innerParse(self, inn, curr, alloc)) else {
                        std.debug.print("missing field {s}\n", .{name});
                        return error.MissingField;
                    }
                    curr = try self.takeTagType();
                }
                try meta_util.fillDefaultStructValues(T, &res, &fields_seen);
            }
            return res;
        },
        .optional => |opt| return try innerParse(self, opt.child, tag, alloc),
        .@"enum" => |e| {
            if (std.meta.hasFn(T, "readNbt")) {
                return T.readNbt(alloc, self, tag);
            }
            if (e.is_exhaustive)
                return @enumFromInt(try innerParse(self, e.tag_type, tag))
            else
                return std.enums.fromInt(T, try innerParse(self, e.tag_type, tag)) orelse error.InvalidEnumVariant;
        },
        .@"union" => {
            if (std.meta.hasFn(T, "readNbt")) {
                return T.readNbt(alloc, self, tag);
            }
            @compileError("TODO");
        },
        .vector => |vec| {
            if (try self.takeChildTag(tag)) |child| {
                if (try self.takeLen() != vec.len) return error.SizeError;
                var res: [vec.len]vec.child = undefined;
                for (&res) |*re|
                    re.* = try innerParse(self, vec.child, child);
                return res;
            } else return error.WrongTag;
        },
        else => @compileError("unsupported type " ++ @typeName(T)),
    }
    unreachable;
}
