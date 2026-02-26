const std = @import("std");
const nbt = @import("root.zig");

pub fn testVal(val: anytype, gpa: std.mem.Allocator) !void {
    var w = std.Io.Writer.Allocating.init(gpa);
    defer w.deinit();
    try nbt.write(&w.writer, val, true);
    var r = std.Io.Reader.fixed(w.written());
    var arena = std.heap.ArenaAllocator.init(gpa);

    defer arena.deinit();
    const alloc = arena.allocator();
    const val2 = try nbt.readLeaky(&r, @TypeOf(val), true, alloc);
    var w2 = std.Io.Writer.Allocating.init(gpa);
    defer w2.deinit();
    try nbt.write(&w2.writer, val2, true);
    try std.testing.expectEqualSlices(u8, w.written(), w2.written());
}
