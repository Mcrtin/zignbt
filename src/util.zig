const std = @import("std");
pub fn castInt(val: anytype, T: type) !T {
    if (@TypeOf(val) == T) return val;
    const from = @typeInfo(@TypeOf(val)).int;
    const to = @typeInfo(T).int;
    if (to.bits == from.bits) return @bitCast(val);
    if (val < std.math.minInt(T) or std.math.maxInt(T) < val) return error.CastError;
    return @intCast(val);
}

pub fn stringHashMapType(T: type) ?type {
    switch (@typeInfo(T)) {
        .@"struct" => {},
        else => return null,
    }
    if (std.meta.hasMethod(T, "put") and @hasDecl(T, "empty") and @TypeOf(T.empty) == T) {
        const ty = @typeInfo(@TypeOf(T.put));
        const params = ty.@"fn".params;
        if (params.len == 4 and params[1].type.? == std.mem.Allocator and params[2].type.? == []const u8)
            return params[3].type.?;
    }
    return null;
}

/// from std.json.static
pub fn fillDefaultStructValues(comptime T: type, r: *T, fields_seen: *[@typeInfo(T).@"struct".fields.len]bool) !void {
    inline for (@typeInfo(T).@"struct".fields, 0..) |field, i| {
        if (!fields_seen[i]) {
            if (field.defaultValue()) |default| {
                @field(r, field.name) = default;
            } else {
                std.debug.print(" {s} missing field {s}\n", .{ @typeName(T), field.name });
                return error.MissingField;
            }
        }
    }
}

const testing = std.testing;

test "castInt same type returns value" {
    const v: i32 = 42;
    const r = try castInt(v, i32);
    try testing.expectEqual(@as(i32, 42), r);
}

test "castInt bitcast same size different signedness" {
    const v: u32 = 0xFFFF_FFFF;
    const r = try castInt(v, i32);
    try testing.expectEqual(@as(i32, -1), r);
}

test "castInt smaller target within range" {
    const v: i32 = 100;
    const r = try castInt(v, i8);
    try testing.expectEqual(@as(i8, 100), r);
}

test "castInt fails when out of range" {
    const v: i32 = 1000;
    try testing.expectError(error.CastError, castInt(v, i8));
}

test "castInt unsigned to signed in range" {
    const v: u8 = 127;
    const r = try castInt(v, i8);
    try testing.expectEqual(@as(i8, 127), r);
}

test "castInt unsigned to signed out of range" {
    const v: u8 = 255;
    try testing.expectError(error.CastError, castInt(v, i8));
}

test "stringHashMapType detects std.StringHashMap value type" {
    const Map = std.StringHashMap(u32);
    const detected = stringHashMapType(Map);
    try testing.expect(detected != null);
    try testing.expectEqual(u32, detected.?);
}

test "stringHashMapType returns null for non-map struct" {
    const S = struct {
        a: i32,
    };
    try testing.expectEqual(@as(?type, null), stringHashMapType(S));
}

test "stringHashMapType returns null for non-struct" {
    try testing.expectEqual(@as(?type, null), stringHashMapType(i32));
}

const TestStruct = struct {
    a: i32 = 5,
    b: i32 = 10,
    c: i32,
};

test "fillDefaultStructValues fills missing defaults" {
    var s = TestStruct{
        .a = undefined,
        .b = undefined,
        .c = 99,
    };

    var seen = [_]bool{ false, false, true };

    try fillDefaultStructValues(TestStruct, &s, &seen);

    try testing.expectEqual(@as(i32, 5), s.a);
    try testing.expectEqual(@as(i32, 10), s.b);
    try testing.expectEqual(@as(i32, 99), s.c);
}

test "fillDefaultStructValues keeps seen fields untouched" {
    var s = TestStruct{
        .a = 1,
        .b = undefined,
        .c = 3,
    };

    var seen = [_]bool{ true, false, true };

    try fillDefaultStructValues(TestStruct, &s, &seen);

    try testing.expectEqual(@as(i32, 1), s.a);
    try testing.expectEqual(@as(i32, 10), s.b);
    try testing.expectEqual(@as(i32, 3), s.c);
}

test "fillDefaultStructValues errors on missing non-default field" {
    const S = struct {
        a: i32 = 1,
        b: i32,
    };

    var s = S{
        .a = undefined,
        .b = undefined,
    };

    var seen = [_]bool{ false, false };

    try testing.expectError(error.MissingField, fillDefaultStructValues(S, &s, &seen));
}
