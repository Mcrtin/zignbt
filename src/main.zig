const std = @import("std");
const nbt = @import("zignbt");

// VerticalPlacement: []const u8,
// BiomeType: enum {
//     pub const is_string = {};
//     WRAM,
//     COLD,
// },
// C: i8,
// CA: BlockState,
// CB: BlockState,
// CC: BlockState,
// CD: BlockState,
// Chest: bool,
// D: i32,
// Depth: i32,
// Entrances: [][]i32,
// EntryDoor: []const u8,
// ground_level_data: i32,
// hasPlacedChest0: bool,
// hasPlacedChest1: bool,
// hasPlacedChest2: bool,
// hasPlacedChest3: bool,
// Height: i32,
// HPos: i32,
// hps: bool,
// hr: bool,
// integrity: f32,
// isBeached: bool,
// isLarge: bool,
// junction: []struct {
//     source_x: i32,
//     source_ground_y: i32,
//     source_z: i32,
//     delta_y: i32,
//     dest_proj: enum {
//         pub const is_string = {};
//         terrain_matching,
//         rigid,
//     },
// },
// Left: bool,
// leftHeigh: bool,
// leftLow: bool,
// Length: bool,
// liquid_settings: []const u8,
// Mirror: []const u8,
// Mob: bool,
// MST: i32,
// Num: i32,
// placedHiddenChest: bool,
// placedMainChest: bool,
// placedTrap1: bool,
// placedTrap2: bool,
// pool_element: struct {
//     element_type: []const u8,
//     location: []const u8,
//     processors: []const u8,
//     projection: []const u8,
//     // processors: struct {
//     //     processors: []nbt.Value,
//     // },
//
// },
// PosX: i32,
// PosY: i32,
// PosZ: i32,
// properties: struct {
//     overgrown: i32,
//     moistness: f32,
//     replace_with_blackstone: bool,
//     vines: bool,
//     cold: bool,
//     air_pocket: bool,
// },
// Right: bool,
// rightHigh: bool,
// rightLow: bool,
// Rot: enum {
//     pub const is_string = {};
//     COUNTERCLOCKWISE_90,
//     NONE,
//     CLOCKWISE_90,
//     CLOCKWISE_180,
// },
// sc: bool,
// Seed: i32,
// Source: bool,
// steps: i32,
// T: enum(i32) { none = 0 , left = 1, right = 2 },
// Tall: bool,
// Template: []const u8,
// Terrace: bool,
// tf: bool,
// TPX: i32,
// TPY: i32,
// TPZ: i32,
// Type: enum (i8) {plains = 0, desert = 1, savanna = 2, taiga =3},
const Heightmap = enum {
    MOTION_BLOCKING,
    MOTION_BLOCKING_NO_LEAVES,
    OCEAN_FLOOR,
    OCEAN_FLOOR_WG,
    WORLD_SURFACE,
    WORLD_SURFACE_WG,
};
const Status = enum {
    pub const is_string = {};
    @"minecraft:empty",
    @"minecraft:structure_starts",
    @"minecraft:structure_references",
    @"minecraft:biomes",
    @"minecraft:noise",
    @"minecraft:surface",
    @"minecraft:carvers",
    @"minecraft:liquid_carvers",
    @"minecraft:features",
    @"minecraft:light",
    @"minecraft:initialize_light",
    @"minecraft:spawn",
    @"minecraft:full",
};

const BlockEntity = struct {
    id: []const u8,
    keepPacked: ?bool,
    x: i32,
    y: i32,
    z: i32,
    components: std.StringArrayHashMapUnmanaged(nbt.Value) = .empty,
    @"trailing\n": std.StringArrayHashMapUnmanaged(nbt.Value),
};
const Section = struct {
    block_states: struct {
        data: ?[]i64,
        palette: []const BlockState,
    },
    biomes: ?struct { palette: [][]const u8, data: ?[]i64 } = null,
    BlockLight: ?[2048]i8 = null,
    SkyLight: ?[2048]i8 = null,
    Y: i8,
};

const Entity = struct {
    Air: i16,
    CustomName: ?nbt.Value,
    CustomNameVisible: ?bool,
    data: ?std.StringArrayHashMapUnmanaged(nbt.Value),
    fall_distance: f64,
    Fire: i16,
    Glowing: ?bool,
    HasVisualFire: ?bool,
    id: []const u8,
    Invulnerable: bool,
    Motion: [3]f64,
    NoGravity: ?bool,
    OnGround: bool,
    Passengers: ?[]@This(),
    PortalCooldown: i32,
    Pos: [3]f64,
    Rotation: [2]f32,
    Silent: ?bool,
    Tags: ?[][]const u8,
    TicksFrozen: ?i32,
    UUID: [4]u32,

    @"trailing\n": std.StringArrayHashMapUnmanaged(nbt.Value),
};
const CarvingInnerProtoChunk = struct {
    xPos: i32,
    yPos: i32,
    zPos: i32,
    block_entities: []BlockEntity,
    LastUpdate: i64,
    structures: Structures,
    InhabitedTime: i64,
    Heightmaps: std.enums.EnumFieldStruct(Heightmap, ?[]i64, null),
    sections: []Section,
    entities: []Entity,
    block_ticks: []TileTick,
    carving_mask: []i64,
    PostProcessing: [24][]i16 = @splat(&.{}),
    DataVersion: i32,
    fluid_ticks: []TileTick,
};
const InnerProtoChunk = struct {
    xPos: i32,
    yPos: i32,
    zPos: i32,
    block_entities: []BlockEntity,
    LastUpdate: i64,
    structures: Structures,
    InhabitedTime: i64,
    Heightmaps: std.enums.EnumFieldStruct(Heightmap, ?[]i64, null),
    sections: []Section,
    entities: []Entity,
    block_ticks: []TileTick,
    PostProcessing: [24][]i16 = @splat(&.{}),
    DataVersion: i32,
    fluid_ticks: []TileTick,
};

const BlockState = struct {
    Name: []const u8,
    Properties: std.StringArrayHashMapUnmanaged(nbt.Value) = .empty,
};

const Structures = struct {
    references: std.StringArrayHashMapUnmanaged([]packed struct { x: i32, z: i32 }),
    starts: std.StringArrayHashMapUnmanaged(struct {
        Children: ?[]struct {
            BB: [6]i32,
            O: i32,
            id: []const u8,
            GD: i32,
            @"trailing\n": std.StringArrayHashMapUnmanaged(nbt.Value),
        },
        ChunkX: ?i32,
        ChunkZ: ?i32,
        id: []const u8,
        Processed: ?[]struct { X: i32, Z: i32 },
        references: ?i32,
    }),
};
const TileTick = struct {
    i: []const u8,
    p: i32,
    t: i32,
    x: i32,
    y: i32,
    z: i32,
};
const InnerChunk = struct {
    Status: Status,
    xPos: i32,
    yPos: i32,
    zPos: i32,
    LastUpdate: i64,
    block_entities: []const BlockEntity,
    structures: Structures,
    InhabitedTime: i64,
    Heightmaps: std.enums.EnumFieldStruct(Heightmap, ?[]const i64, null),
    sections: []const Section,
    block_ticks: []const TileTick,
    isLightOn: bool,
    PostProcessing: [24][]const i16 = @splat(&.{}),
    DataVersion: i32,
    fluid_ticks: []const TileTick,
};
const Chunk = struct {
    @"trailing\n": StatusChunk,
};

const StatusChunk = nbt.FlatUnion(union(Status) {
    @"minecraft:empty": InnerProtoChunk,
    @"minecraft:structure_starts": InnerProtoChunk,
    @"minecraft:structure_references": InnerProtoChunk,
    @"minecraft:biomes": InnerProtoChunk,
    @"minecraft:noise": InnerProtoChunk,
    @"minecraft:surface": InnerProtoChunk,
    @"minecraft:carvers": CarvingInnerProtoChunk,
    @"minecraft:liquid_carvers": CarvingInnerProtoChunk,
    @"minecraft:features": CarvingInnerProtoChunk,
    @"minecraft:light": CarvingInnerProtoChunk,
    @"minecraft:initialize_light": CarvingInnerProtoChunk,
    @"minecraft:spawn": CarvingInnerProtoChunk,
    @"minecraft:full": InnerChunk,
});

const SECTOR_BYTES = 4 << 10;

const Compression = enum(u8) {
    gzip = 1,
    zlib = 2,
    none = 3,
    lz4 = 4,
    custom = 127,
};
const ChunkAlias = nbt.Value;
const ChunkLoadResult = struct { offset: u24, len: u8, chunk: ChunkAlias };

pub fn loadChunk(
    r: *std.Io.File.Reader,
    alloc: std.mem.Allocator,
    chunk_x: u5,
    chunk_z: u5,
) !?ChunkLoadResult {
    const index = (@as(usize, chunk_z) * (std.math.maxInt(u5) + 1) + @as(usize, chunk_x)) * @sizeOf(u32);
    try r.seekTo(index);

    const offset = try r.interface.takeInt(u24, .big);
    const len = try r.interface.takeInt(u8, .big);

    if (offset == 0) return null;

    try r.seekTo(@as(usize, offset) * SECTOR_BYTES);
    const length: u31 = @intCast(try r.interface.takeInt(i32, .big));
    std.debug.print("load len: {d}\n", .{length});
    std.debug.assert(length <= @as(usize, len) * SECTOR_BYTES);
    std.debug.assert(length > @as(usize, len - 1) * SECTOR_BYTES);
    var buf: [1024]u8 = undefined;
    var reader = r.interface.limited(.limited(length), &buf);
    defer std.debug.assert(reader.remaining == .nothing);

    var compress_buf: [std.compress.flate.max_window_len]u8 = undefined;
    const compression_type = try reader.interface.takeEnum(Compression, .big);

    switch (compression_type) {
        inline .zlib, .gzip => {
            var decomp = std.compress.flate.Decompress.init(&reader.interface, std.meta.stringToEnum(std.compress.flate.Container, @tagName(compression_type)).?, &compress_buf);
            return .{ .offset = offset, .len = len, .chunk = try nbt.readLeaky(&decomp.reader, ChunkAlias, true, alloc) };
        },
        .none => return .{ .offset = offset, .len = len, .chunk = try nbt.readLeaky(&reader.interface, ChunkAlias, true, alloc) },
        else => return error.Unsupported,
    }
    unreachable;
}

pub fn main(init: std.process.Init) !void {
    var args = try init.minimal.args.iterateAllocator(init.gpa);
    _ = args.skip();
    const f = try std.Io.Dir.cwd().openFile(init.io, args.next().?, .{});
    defer f.close(init.io);
    var rbuf: [1024]u8 = undefined;
    var r = f.reader(init.io, &rbuf);
    var arena = std.heap.ArenaAllocator.init(init.gpa);

    defer arena.deinit();
    const alloc = arena.allocator();
    var f2 = try std.Io.Dir.cwd().createFile(init.io, args.next().?, .{});
    defer f2.close(init.io);
    var wbuf: [1024]u8 = undefined;
    var w = f2.writer(init.io, &wbuf);
    defer w.interface.flush() catch {};
    const chunk = (try loadChunk(&r, alloc, 0, 0)).?;
    std.debug.print("offset: {d} loc: {d}\n", .{ chunk.offset, chunk.len });
    // try saveChunkToRegion(gpa, &f2, 0, 0, chunk.chunk);
    // var res: nbt.Value = .{ .Compound = try .init(
    //     gpa,
    //     &.{"Status"},
    // ) };

    const comp = chunk.chunk.Compound;
    std.debug.print("idk: {any}\n", .{comp.get("sections").?.List[0].Compound.keys()});
    try writeChunk(init.io, &w, 0, 0, @as(InnerChunk, .{
        .Status = .@"minecraft:full",
        .zPos = @as(i32, 0),
        .block_entities = &.{},
        .yPos = @as(i32, -64),
        .LastUpdate = @as(i64, 0),
        .structures = .{ .references = .empty, .starts = .empty },
        .InhabitedTime = @as(i64, 0),
        .xPos = @as(i32, 0),
        .Heightmaps = .{
            .MOTION_BLOCKING = null,
            .MOTION_BLOCKING_NO_LEAVES = null,
            .OCEAN_FLOOR = null,
            .OCEAN_FLOOR_WG = null,
            .WORLD_SURFACE = null,
            .WORLD_SURFACE_WG = null,
        },
        .sections = &.{.{
            .block_states = .{
                .data = null,
                .palette = @as([]const BlockState, &.{
                    .{
                        .Name = "minecraft:stone",
                        .Properties = .empty,
                    },
                }),
            },
            .biomes = null,
            // .BlockLight = comp.get("sections").?.List[0].Compound.get("BlockLight").?,
            // .SkyLight = comp.get("sections").?.List[0].Compound.get("SkyLight").?,
            .Y = 4,
            // SkyLight: ?[2048]i8,
            // .Y = @as(i8, 4),
            //
        }},
        .block_ticks = &.{},
        .DataVersion = @as(i64, 4440),
        .fluid_ticks = &.{},
        .isLightOn = false,
    }));
    // .{
    //     .Status = "minecraft:full",
    //     .xPos = @as(i32, 0),
    //     .yPos = @as(i32, -64),
    //     .zPos = @as(i32, 0),
    //     .block_entities = &.{},
    //     .LastUpdate = @as(i64, 0),
    //     .structures = .{ .References = .{}, .Starts = .{} },
    //     .InhabitedTime = @as(i64, 0),
    //     .Heightmaps = .{},
    //     .sections = comp.get("sections"),
    //     .entities = &.{},
    //     .block_ticks = &.{},
    //     .PostProcessing = @as([24][]i16, @splat(&.{})),
    //     .DataVersion = @as(i32, 4440),
    //     .fluid_ticks = &.{},
    //     .isLightOn = false,
    // }
    // var stdout = std.fs.File.stdout();
    // var outb: [1024]u8 = undefined;
    // var outw = stdout.writer(&outb);
    // defer outw.interface.flush() catch {};
    // try nbt.write(&outw.interface, chunk.chunk, true);
}
pub fn writeChunk(
    io: std.Io,
    w: *std.Io.File.Writer,
    chunk_x: u5,
    chunk_z: u5,
    // offset: u24,
    chunk: anytype,
) !void {
    const index = (@as(usize, chunk_z) * (std.math.maxInt(u5) + 1) + @as(usize, chunk_x)) * @sizeOf(u32);
    try w.seekTo(index);

    const offset = 2;
    try w.interface.writeInt(u24, offset, .big);
    try w.interface.flush();

    try w.seekTo(SECTOR_BYTES + index);
    try w.interface.writeInt(i32, @intCast(std.Io.Clock.real.now(io).toMilliseconds()), .big);
    try w.interface.flush();
    try w.seekTo(@as(usize, offset) * SECTOR_BYTES + @sizeOf(i32) + @sizeOf(Compression));

    try nbt.write(&w.interface, chunk, true);

    try w.interface.flush();
    const length = w.pos - (@as(u64, offset) * SECTOR_BYTES + @sizeOf(i32));
    const len = std.math.divCeil(u64, length, SECTOR_BYTES) catch unreachable;
    try w.interface.splatByteAll(0, len * SECTOR_BYTES - length - @sizeOf(i32));
    try w.interface.flush();
    try w.seekTo(index + 3);
    try w.interface.writeInt(u8, @intCast(len), .big);
    try w.interface.flush();
    std.debug.print("length: {d}, len: {d}\n", .{ length, len });
    try w.seekTo(@as(usize, offset) * SECTOR_BYTES);
    std.debug.assert(length <= @as(usize, len) * SECTOR_BYTES);
    std.debug.assert(length > @as(usize, len - 1) * SECTOR_BYTES);
    try w.interface.writeInt(u32, @intCast(length), .big);
    try w.interface.writeInt(u8, @intFromEnum(Compression.none), .big);
    try w.interface.flush();
}

// pub fn saveChunkToRegion(
//     allocator: std.mem.Allocator,
//     file: *std.fs.File,
//     chunk_x: i32,
//     chunk_z: i32,
//     chunk: anytype,
// ) !void {
//     _ = chunk; // autofix
//     const HEADER_BYTES = SECTOR_BYTES * 2;
//
//     // Ensure header exists
//     const stat = try file.stat();
//     if (stat.size < HEADER_BYTES) {
//         try file.setEndPos(HEADER_BYTES);
//         try file.seekTo(0);
//         try file.writeAll(&[_]u8{0} ** HEADER_BYTES);
//     }
//
//     // Local chunk coordinates (0–31)
//     const local_x: u32 = @intCast(@mod(chunk_x, 32));
//     const local_z: u32 = @intCast(@mod(chunk_z, 32));
//     const index: u32 = local_x + local_z * 32;
//
//     std.debug.print("hi4\n", .{});
//     // --- Compress (zlib) ---
//     var compressed = std.Io.Writer.Allocating.init(allocator);
//     defer compressed.deinit();
//     var compress_buf: [std.compress.flate.history_len]u8 = undefined;
//
//     {
//         var compressor = std.compress.flate.Compress.init(&compressed.writer, &compress_buf, .{ .container = .zlib });
//         try compressor.writer.writeAll("hi");
//         std.debug.print("hi5\n", .{});
//         try compressor.writer.flush();
//         std.debug.print("hi7\n", .{});
//
//         // try nbt.write(&compressor.writer, chunk, true);
//         try compressor.end();
//         std.debug.print("hi6\n", .{});
//     }
//
//     const data_len = compressed.written().len + 1; // +1 for compression type
//
//     std.debug.print("hi3\n", .{});
//     // Full chunk payload (length + type + data)
//     var chunk_buf = std.Io.Writer.Allocating.init(allocator);
//     defer chunk_buf.deinit();
//
//     {
//         const w = &chunk_buf.writer;
//         try w.writeInt(u32, @intCast(data_len), .big);
//         try w.writeByte(2); // zlib compression
//         try w.writeAll(compressed.written());
//     }
//
//     // --- Find write position (append at end) ---
//     const file_size = (try file.stat()).size;
//     const sector_offset: u32 = @intCast(file_size / SECTOR_BYTES);
//
//     // Pad to sector alignment
//     const padding = SECTOR_BYTES - (chunk_buf.written().len % SECTOR_BYTES);
//     if (padding != SECTOR_BYTES) {
//         try chunk_buf.writer.splatByteAll(0, padding);
//     }
//
//     const sector_count: u32 = @intCast(chunk_buf.written().len / SECTOR_BYTES);
//
//     // --- Write chunk data ---
//     try file.seekTo(file_size);
//     try file.writeAll(chunk_buf.written());
//
//     std.debug.print("hi1\n", .{});
//     // --- Write location entry ---
//     const location: u32 = (sector_offset << 8) | sector_count;
//
//     {
//         try file.seekTo(index * 4);
//         var w = file.writer(&.{});
//         defer w.interface.flush() catch {};
//         try w.interface.writeInt(u32, location, .big);
//     }
//
//     std.debug.print("hi2\n", .{});
//     // --- Write timestamp ---
//     const timestamp: u32 = @intCast(std.time.timestamp());
//     {
//         try file.seekTo(SECTOR_BYTES + index * 4);
//         var w = file.writer(&.{});
//         defer w.interface.flush() catch {};
//         try w.interface.writeInt(u32, timestamp, .big);
//     }
// }
