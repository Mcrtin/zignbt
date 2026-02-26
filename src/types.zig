const std = @import("std");
const nbt = @import("root.zig");

pub fn BoundedArray(T: type, bound: comptime_int) type {
    return struct {
        len: std.math.IntFittingRange(0, bound) = 0,
        arr: [bound]T = undefined,

        pub fn items(self: *@This()) []T {
            return self.arr[0..self.len];
        }
        pub fn a(self: *@This()) std.ArrayList(T) {
            return std.ArrayList(T){ .capacity = bound, .items = self.items() };
        }

        pub const defaultNbtType = nbt.TagType.fromType(@FieldType(@This(), "arr")).?;

        pub fn readNbt(alloc: ?std.mem.Allocator, r: nbt.Reader, tag: nbt.TagType) !@This() {
            if (try r.takeChildTag(tag)) |child| {
                var res: @This() = .{};
                const len = try r.takeLen();
                if (len > bound) return error.SizeError;
                for (0..len) |_|
                    res.a().appendAssumeCapacity(try r.innerParse(T, child, alloc));
                return res;
            } else return error.WrongTag;
        }

        pub fn writeNbt(self: @This(), w: nbt.Writer) !void {
            try nbt.writeNbtType(w, self.items());
        }

        pub fn nbtType(self: @This()) nbt.TagType {
            return nbt.TagType.fromVal(self.items());
        }

        pub fn deinit(_: @This(), _: std.mem.Allocator) void {}
    };
}

pub const Value = union(enum) {
    Byte: i8,
    Short: i16,
    Int: i32,
    Long: i64,
    Float: f32,
    Double: f64,
    ByteArray: []i8,
    String: []const u8,
    List: []Value,
    Compound: std.StringArrayHashMapUnmanaged(Value),
    IntArray: []i32,
    LongArray: []i64,

    pub const defaultNbtType = .End;

    pub fn readNbt(alloc: ?std.mem.Allocator, r: nbt.Reader, tag: nbt.TagType) !@This() {
        return switch (tag) {
            .End => error.WrongTag,
            inline else => |t| @unionInit(@This(), @tagName(t), try r.innerParse(@FieldType(@This(), @tagName(t)), t, alloc)),
        };
    }

    pub fn writeNbt(self: @This(), w: nbt.Writer) !void {
        switch (std.meta.activeTag(self)) {
            inline else => |t| try w.innerWrite(@field(self, @tagName(t))),
        }
    }

    pub fn nbtType(self: @This()) nbt.TagType {
        return std.meta.stringToEnum(nbt.TagType, @tagName(std.meta.activeTag(self))).?;
    }

    //TODO: needed?
    pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
        switch (self) {
            inline .ByteArray, .String, .IntArray, .LongArray => |mem| alloc.free(mem),
            .List => |l| {
                for (l) |v| v.deinit(alloc);
                alloc.free(l);
            },
            .Compound => |c| {
                for (c.keys()) |k| alloc.free(k);
                for (c.values()) |v| v.deinit(alloc);
                var mut = c;
                mut.deinit(alloc);
            },
            else => {},
        }
    }

    pub fn printShape(self: @This(), w: *std.Io.Writer) !void {
        switch (self) {
            .List => |l| {
                try w.writeAll("[]");
                if (l.len == 0) try w.writeAll("void") else try l[0].printShape(w);
            },
            .Compound => |c| {
                var it = c.iterator();
                try w.writeAll("struct { ");
                while (it.next()) |item| {
                    try w.writeAll(item.key_ptr.*);
                    try w.writeAll(": ");
                    try item.value_ptr.*.printShape(w);
                    try w.writeAll(", ");
                }
                try w.writeAll("}");
            },
            inline else => |t| try w.writeAll(@typeName(@TypeOf(t))),
        }
    }
};
