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
    block_entities: []struct { id: []const u8, keepPacked: bool = false, x: i32, y: i32, z: i32, components: std.StringArrayHashMapUnmanaged(nbt.Value) = .empty, @"trailing\n": std.StringArrayHashMapUnmanaged(nbt.Value) },
    yPos: i32,
    LastUpdate: i64,
    structures: struct {
        References: std.StringArrayHashMapUnmanaged([]i64),
        starts: std.StringArrayHashMapUnmanaged(nbt.Value),
    },
    InhabitedTime: i64,
    xPos: i32,
    Heightmaps: std.enums.EnumFieldStruct(Heightmap, []i64, &.{}),
    sections: []struct {
        block_states: struct {
            data: []i64 = &.{},
            palette: []struct { Name: []const u8, Properties: std.StringArrayHashMapUnmanaged(nbt.Value) = .empty },
        },
        biomes: struct { palette: [][]const u8, data: []i64 = &.{} },
        BlockLight: ?[2048]i8 = null,
        SkyLight: ?[2048]i8 = null,
        Y: i8,
    },
    entities: []std.StringArrayHashMapUnmanaged(nbt.Value) = &.{},
    isLightOn: ?bool = null,
    block_ticks: []std.StringArrayHashMapUnmanaged(nbt.Value),
    carving_mask: []i64 = &.{},
    PostProcessing: [][]i16,
    DataVersion: i32,
    fluid_ticks: []std.StringArrayHashMapUnmanaged(nbt.Value),
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
    gpa: std.mem.Allocator,
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
            try printType(&decomp.reader, gpa);
        },
        .zlib => {
            var decomp = std.compress.flate.Decompress.init(&reader.interface, .zlib, &compress_buf);
            if (chunk_x == 12 and chunk_z == 16) {
                const v = try nbt.readLeaky(&decomp.reader, nbt.Value, true, gpa);
                var errbuf: [200]u8 = undefined;
                try v.printShape(std.debug.lockStderrWriter(&errbuf));
                std.debug.unlockStdErr();
            } else try printType(&decomp.reader, gpa);
        },
        .none => try printType(&reader.interface, gpa),
        else => return error.Unsupported,
    }
}

fn printType(r: *std.Io.Reader, gpa: std.mem.Allocator) !void {
    var arena = std.heap.ArenaAllocator.init(gpa);

    defer arena.deinit();
    const alloc = arena.allocator();
    const chunk = try nbt.readLeaky(r, Chunk, true, alloc);
    try nbt.testVal(chunk, gpa);
}

pub fn main() !void {
    var a = std.heap.DebugAllocator(.{}){};
    defer _ = a.deinit();
    const gpa = a.allocator();
    var args = std.process.args();
    _ = args.skip();
    const f = try std.fs.cwd().openFile(args.next().?, .{});
    var rbuf: [1024]u8 = undefined;
    var r = f.reader(&rbuf);
    for (0..31) |x| for (0..31) |z| {
        std.debug.print("x: {d} z: {d}\n", .{ x, z });
        try loadChunk(&r, gpa, @intCast(x), @intCast(z));
    };
}
