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

    pub fn expect(self: @This(), expected: TagType) !void {
        if (self != expected) {
            std.debug.print("got: {any}\n", .{self});
            return error.WrongTag;
        }
    }

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
            } else return .Compound,
            .optional => @compileError("optionals are not supported in this context"),
            .@"enum" => |e| inline for (e.decls) |decl| {
                if (comptime std.mem.eql(u8, decl.name, "defaultNbtType")) return T.defaultNbtType;
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
