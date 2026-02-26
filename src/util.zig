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
