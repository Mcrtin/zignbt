const std = @import("std");
const nbt = @import("zignbt");

const Heightmap = enum {
    MOTION_BLOCKING,
    MOTION_BLOCKING_NO_LEAVES,
    OCEAN_FLOOR,
    OCEAN_FLOOR_WG,
    WORLD_SURFACE,
    WORLD_SURFACE_WG,
};

const Chunk = struct {
    Status: []const u8,
    zPos: i32,
    block_entities: []struct { id: []const u8, keepPacked: bool = false, x: i32, y: i32, z: i32, components: std.StringArrayHashMapUnmanaged(nbt.NbtValue) = .empty, @"trailing\n": std.StringArrayHashMapUnmanaged(nbt.NbtValue) },
    yPos: i32,
    LastUpdate: i64,
    structures: struct {
        References: std.StringArrayHashMapUnmanaged([]i64),
        starts: std.StringArrayHashMapUnmanaged(nbt.NbtValue),
    },
    InhabitedTime: i64,
    xPos: i32,
    Heightmaps: std.enums.EnumFieldStruct(Heightmap, []i64, &.{}),
    sections: []struct {
        block_states: struct {
            data: []i64 = &.{},
            palette: []struct { Name: []const u8, Properties: std.StringArrayHashMapUnmanaged(nbt.NbtValue) = .empty },
        },
        biomes: struct { palette: [][]const u8, data: []i64 = &.{} },
        BlockLight: ?[2048]i8 = null,
        SkyLight: ?[2048]i8 = null,
        Y: i8,
    },
    entities: []std.StringArrayHashMapUnmanaged(nbt.NbtValue) = &.{},
    isLightOn: ?bool = null,
    block_ticks: []std.StringArrayHashMapUnmanaged(nbt.NbtValue),
    carving_mask: []i64 = &.{},
    PostProcessing: [][]i16,
    DataVersion: i32,
    fluid_ticks: []std.StringArrayHashMapUnmanaged(nbt.NbtValue),
};

const SECTOR_BYTES = 4096;

const Compression = enum(u8) {
    gzip = 1,
    zlib = 2,
    none = 3,
    lz4 = 4,
    custom = 127,
};

pub fn loadChunk(
    r: *std.fs.File.Reader,
    chunk_x: u5,
    chunk_z: u5,
) !void {
    const index = (@as(usize, chunk_z) * (std.math.maxInt(u5) + 1) + @as(usize, chunk_x)) * @sizeOf(u32);
    try r.seekTo(index);

    const offset = try r.interface.takeInt(u24, .big);
    const len = try r.interface.takeInt(u8, .big);

    if (offset == 0) return;

    try r.seekTo(@as(usize, offset) * SECTOR_BYTES);
    const length: u31 = @intCast(try r.interface.takeInt(i32, .big));
    std.debug.assert(length <= @as(usize, len) * SECTOR_BYTES);
    std.debug.assert(length > @as(usize, len - 1) * SECTOR_BYTES);
    var buf: [1024]u8 = undefined;
    var reader = r.interface.limited(.limited(length), &buf);

    var compress_buf: [std.compress.flate.max_window_len]u8 = undefined;
    const compression_type = try reader.interface.takeEnum(Compression, .big);

    switch (compression_type) {
        .gzip => {
            var decomp = std.compress.flate.Decompress.init(&reader.interface, .gzip, &compress_buf);
            try printtype(&decomp.reader);
        },
        .zlib => {
            var decomp = std.compress.flate.Decompress.init(&reader.interface, .zlib, &compress_buf);
            try printtype(&decomp.reader);
        },
        .none => try printtype(&reader.interface),
        else => return error.Unsupported,
    }
}
fn printtype(r: *std.Io.Reader) !void {
    var a = std.heap.DebugAllocator(.{}){};
    // defer _ = a.detectLeaks();
    defer _ = a.deinit();
    const gpa = a.allocator();
    var arena = std.heap.ArenaAllocator.init(gpa);

    defer arena.deinit();
    const alloc = arena.allocator();
    const chunk = try nbt.readLeaky(r, Chunk, true, alloc);
    // const v = try zignbt.read(r, zignbt.NbtValue, true, alloc);
    // var buf: [200]u8 = undefined;
    // var f = std.fs.File.stdout();
    var w = std.Io.Writer.Allocating.init(gpa);
    defer w.deinit();
    // try v.printShape(&w.interface);
    // try w.interface.writeAll("\n");
    try nbt.write(&w.writer, &chunk, true);
    try w.writer.flush();
    var r2 = std.Io.Reader.fixed(w.written());
    const chunk2 = try nbt.readLeaky(&r2, Chunk, true, alloc);

    if (!std.meta.eql(chunk, chunk2)) std.debug.print("{any}\n", .{chunk2});
}
pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();
    const f = try std.fs.cwd().openFile(args.next().?, .{});
    var rbuf: [1024]u8 = undefined;
    var r = f.reader(&rbuf);
    for (0..1) |x| for (0..1) |z| {
        std.debug.print("x: {d} z: {d}\n", .{ x, z });
        try loadChunk(&r, @intCast(x), @intCast(z));
    };
    // const v = try zignbt.read(&r.interface, zignbt.NbtValue, false);
    // var buf: [200]u8 = undefined;
    // var w = std.fs.File.stdout().writer(&buf);
    // try v.printShape(&w.interface);
    // try zignbt.write(undefined, {}, false);
    // Prints to stderr, ignoring potential errors.
    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    // try zignbt.bufferedPrint();
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
