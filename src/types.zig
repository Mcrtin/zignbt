const nbt = @import("root.zig");
const std = @import("std");

pub fn FlatUnion(U: type) type {
    return struct {
        inner: U,
        pub const NbtType = blk: {
            var fields_len = 1;
            for (@typeInfo(U).@"union".fields) |field| fields_len += @typeInfo(field.type).@"struct".fields.len;

            @setEvalBranchQuota(fields_len * 100);

            var buf: [fields_len][]const u8 = undefined;
            var list: std.ArrayList([]const u8) = .initBuffer(&buf);
            var buf2: [fields_len]type = undefined;
            var list2: std.ArrayList(type) = .initBuffer(&buf2);

            const tag_type = @typeInfo(U).@"union".tag_type.?;
            const tag_type_name = @typeName(tag_type);
            const tag_name = tag_type_name[std.mem.lastIndexOfScalar(u8, tag_type_name, '.').? + 1 ..];
            list.appendAssumeCapacity(tag_name);
            list2.appendAssumeCapacity(tag_type);

            for (@typeInfo(U).@"union".fields) |field| {
                for (@typeInfo(field.type).@"struct".fields) |inner_field| {
                    for (list.items) |item| {
                        if (std.mem.eql(u8, item.name, inner_field.name)) {
                            if (@typeInfo(item.type).optional.child != inner_field.type) @compileError("mismatched types in FlatUnion " ++ @typeName(U) ++ " at field " ++ inner_field.name);
                            break;
                        }
                    } else {
                        list.appendAssumeCapacity(inner_field.name);
                        list2.appendAssumeCapacity(?inner_field.type);
                    }
                }
            }
            break :blk @Struct(
                .auto,
                null,
                list.items,
                list2.items,
                @splat(.{}),
            );
        };

        pub const defaultNbtType = nbt.TagType.Compound;

        pub fn readNbt(alloc: ?std.mem.Allocator, r: nbt.Reader, tag: nbt.TagType) !@This() {
            const nbt_res = try r.innerParse(NbtType, tag, alloc);
            const tag_type = @typeInfo(U).@"union".tag_type.?;
            const tag_type_name = @typeName(tag_type);
            const tag_name = comptime tag_type_name[std.mem.lastIndexOfScalar(u8, tag_type_name, '.').? + 1 ..];
            switch (@field(nbt_res, tag_name)) {
                inline else => |a| {
                    const active = @tagName(a);
                    var init: @FieldType(U, active) = undefined;
                    inline for (@typeInfo(@TypeOf(init)).@"struct".fields) |field| {
                        const instance = @field(nbt_res, field.name);
                        if (@typeInfo(field.type) != .optional and instance == null) return error.CastError;
                        @field(init, field.name) = instance orelse if (@typeInfo(field.type) != .optional) field.defaultValue().? else field.defaultValue() orelse null;
                    }
                    //TODO: verify that no other field was read!
                    return .{ .inner = @unionInit(U, active, init) };
                },
            }
        }

        pub fn writeNbt(self: @This(), w: nbt.Writer) !void {
            const tag = std.meta.activeTag(self.inner);
            try w.writeTagType(nbt.TagType.fromVal(tag).?);
            const tag_type = @typeInfo(U).@"union".tag_type.?;
            const tag_type_name = @typeName(tag_type);
            const tag_name = comptime tag_type_name[std.mem.lastIndexOfScalar(u8, tag_type_name, '.').? + 1 ..];
            try w.writeString(tag_name);
            try w.innerWrite(tag);
            switch (tag) {
                inline else => |a| try w.innerWrite(@field(self.inner, @tagName(a))),
            }
        }

        pub fn deinit(self: @This(), alloc: std.mem.Allocator) void {
            if (std.meta.hasMethod(U, "deinit")) self.inner.deinit(alloc);
        }
    };
}

pub fn BoundedArray(T: type, comptime bound: usize) type {
    return struct {
        len: std.math.IntFittingRange(0, bound) = 0,
        arr: [bound]T = undefined,

        pub fn items(self: *@This()) []T {
            return self.arr[0..self.len];
        }
        pub fn a(self: *@This()) std.ArrayList(T) {
            return std.ArrayList(T){ .capacity = self.arr.len, .items = self.items() };
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
            w.innerWrite(self.items());
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
