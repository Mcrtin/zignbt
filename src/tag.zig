const std = @import("std");
pub const TagType = enum(u8) {
    End = 0,
    Byte = 1,
    Short = 2,
    Int = 3,
    Long = 4,
    Float = 5,
    Double = 6,
    ByteArray = 7,
    String = 8,
    List = 9,
    Compound = 10,
    IntArray = 11,
    LongArray = 12,

    /// Ensures that `self` matches the `expected` tag type.
    ///
    /// Returns `error.WrongTag` if the tag differs.
    /// In debug builds, prints the received tag before returning the error.
    ///
    /// This is primarily used during decoding to validate that the
    /// incoming NBT tag matches the expected Zig type.
    pub fn expect(self: @This(), expected: TagType) !void {
        if (self != expected) {
            std.debug.print("got: {any}\n", .{self});
            return error.WrongTag;
        }
    }

    /// Infers the NBT tag type corresponding to a runtime value `val`.
    ///
    /// Behavior:
    /// - If the value's type defines `nbtType()`, that method is used.
    /// - `[]const u8` → `.String`
    /// - Pointers to single values delegate to their child.
    /// - Slices/arrays/vectors:
    ///     * If empty, fall back to `fromType(T)`
    ///     * If non-empty:
    ///         - `.Byte` elements → `.ByteArray`
    ///         - `.Int` elements  → `.IntArray`
    ///         - `.Long` elements → `.LongArray`
    ///         - otherwise        → `.List`
    /// - Scalars and structs delegate to `fromType`.
    ///
    /// Returns `null` for `void` values.
    ///
    /// This function is intended for NBT serialization, allowing
    /// automatic tag deduction from Zig values.
    pub fn fromVal(val: anytype) ?@This() {
        const T = @TypeOf(val);
        if (std.meta.hasMethod(T, "nbtType")) {
            return val.nbtType();
        }
        switch (@typeInfo(T)) {
            .pointer => |p| {
                if (T == []const u8) {
                    return .String;
                }
                if (p.size == .one) return fromVal(val.*);
                std.debug.assert(p.size == .slice);
                if (val.len == 0) return fromType(T);
                return switch (fromVal(val[0]).?) {
                    .End => unreachable,
                    .Byte => .ByteArray,
                    .Int => .IntArray,
                    .Long => .LongArray,
                    else => .List,
                };
            },
            inline .array, .vector => {
                if (val.len == 0) return fromType(T);
                return switch (fromVal(val[0]).?) {
                    .End => unreachable,
                    .Byte => .ByteArray,
                    .Int => .IntArray,
                    .Long => .LongArray,
                    else => .List,
                };
            },
            else => return fromType(T),
        }
    }

    /// Infers the NBT tag type corresponding to a Zig type `T`.
    ///
    /// Mapping rules:
    /// - `[]const u8` → `.String`
    /// - Slices/arrays/vectors:
    ///     * `u8/i8`  → `.ByteArray`
    ///     * `i32/u32`→ `.IntArray`
    ///     * `i64/u64`→ `.LongArray`
    ///     * otherwise→ `.List`
    /// - `bool` → `.Byte`
    /// - Integers:
    ///     * ≤8 bits   → `.Byte`
    ///     * ≤16 bits  → `.Short`
    ///     * ≤32 bits  → `.Int`
    ///     * ≤64 bits  → `.Long`
    /// - `f32` → `.Float`
    /// - `f64` → `.Double`
    /// - `struct` → `.Compound` unless it defines `defaultNbtType`
    /// - `enum` → underlying tag type unless it defines `defaultNbtType`
    ///
    /// Specialization:
    /// - If `T` declares a `pub const defaultNbtType`, that value
    ///   overrides the inferred mapping.
    ///
    /// Compile-time errors:
    /// - Optionals are unsupported.
    /// - Unions without `defaultNbtType` are unsupported.
    /// - Unsupported or ambiguous types produce a compile error.
    ///
    /// This function is primarily used during serialization to determine
    /// which NBT tag header should be written for a given Zig type.
    pub fn fromType(T: type) ?@This() {
        switch (@typeInfo(T)) {
            .pointer => |pointer| {
                if (T == []const u8) {
                    return .String;
                }
                return switch (fromType(pointer.child).?) {
                    .Byte => .ByteArray,
                    .Int => .IntArray,
                    .Long => .LongArray,
                    else => .List,
                };
            },
            inline .array, .vector => |arr| {
                return switch (fromType(arr.child).?) {
                    .Byte => .ByteArray,
                    .Int => .IntArray,
                    .Long => .LongArray,
                    else => .List,
                };
            },
            .void => return null,
            .bool => return .Byte,
            .int => |int| {
                if (int.bits <= 8) {
                    return .Byte;
                } else if (int.bits <= 16) {
                    return .Short;
                } else if (int.bits <= 32) {
                    return .Int;
                } else if (int.bits <= 64) {
                    return .Long;
                } else @compileError("ambiguous type " ++ @typeName(T));
            },
            .float => |float| {
                if (float.bits == 32) {
                    return .Float;
                } else if (float.bits == 64) {
                    return .Double;
                } else @compileError("unsupported float type " ++ @typeName(T));
            },
            .@"struct" => |s| inline for (s.decls) |decl| {
                if (comptime std.mem.eql(u8, decl.name, "defaultNbtType")) return T.defaultNbtType;
            } else if (s.backing_integer) |int| return TagType.fromType(int).? else return .Compound,
            .optional => @compileError("optionals are not supported in this context"),
            .@"enum" => |e| inline for (e.decls) |decl| {
                if (comptime std.mem.eql(u8, decl.name, "defaultNbtType")) return T.defaultNbtType;
                if (comptime std.mem.eql(u8, decl.name, "is_string")) return .String;
            } else return fromType(e.tag_type),
            .@"union" => |u| {
                inline for (u.decls) |decl| {
                    if (comptime std.mem.eql(u8, decl.name, "defaultNbtType")) return T.defaultNbtType;
                }
                @compileError("TODO " ++ @typeName(T));
            },
            else => @compileError("unsupported type " ++ @typeName(T)),
        }
    }
};
