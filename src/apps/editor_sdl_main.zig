const std = @import("std");
const utils = @import("utils");
const engine = @import("engine");
const zigimg = @import("zigimg");
const core_mod = engine.core;
const swapchain_mod = engine.swapchain;
const render = engine.renderer;
const helper = engine.helper;
const text = engine.textures;
const c = engine.c;
const print = std.debug.print;
const sdl = engine.sdl;
const math = utils.math;
const algo = utils.algo;

// Opaque = 0
// Alpha = 1
// UI = 2

pub const AtlasAliasId_u32 = u32;
pub const SceneId_u32 = u32;

pub const AtlasManager = struct {

    atlas_list: std.ArrayList(Atlas),

    pub fn AddAtlas(self: *AtlasManager, allocator: std.mem.Allocator, atlas: Atlas) !AtlasAliasId_u32 {

        const index = self.atlas_list.items.len;

        try self.atlas_list.append(allocator, atlas);

        return @intCast(index);
    }
};

pub const IndexRange = struct {
    offset: u32 = 0,
    count: u32 = 0,
};

pub const Scene = struct {
    scene_index: u32 = 0,
    atlas_aliases: IndexRange = .{},
    connected_scenes: IndexRange = .{},
};

pub const SceneManager = struct {

    scenes: std.ArrayList(Scene),
    atlas_alias_table: std.ArrayList(AtlasAliasId_u32),
    scene_connection_table: std.ArrayList(SceneId_u32),

    pub fn MakeScene(
        self: *SceneManager, 
        allocator: std.mem.Allocator,
        alias_ids: []const AtlasAliasId_u32,
        connected_scene_ids: []const SceneId_u32 ) !void{
        
        // Reserve space
        try self.atlas_alias_table.appendSlice(allocator, alias_ids);
        try self.scene_connection_table.appendSlice(allocator, connected_scene_ids);

        const alias_offset = self.atlas_alias_table.items.len - alias_ids.len;
        const conn_offset  = self.scene_connection_table.items.len - connected_scene_ids.len;
        
        // Make New Scene
        const scene = Scene{
            .scene_index = @intCast(self.scenes.items.len),
            .atlas_aliases = .{
                .offset = @intCast(alias_offset),
                .count = @intCast(alias_ids.len),
            },
            .connected_scenes = .{
                .offset = @intCast(conn_offset),
                .count = @intCast(connected_scene_ids.len),
            },
        };

        try self.scenes.append(allocator, scene);
    }
};

pub const Sprite = struct {
    atlas_id: u32,
    //uv_rect: Rect,
    default_size: math.Vec2,
};

pub const Atlas = struct {
    width: u32 = 0,
    height: u32 = 0,
    pixels: ?[]u8 = undefined,
    cursor_x: u32 = 0,
    cursor_y: u32 = 0,
    row_h: u32 = 0,
};

pub fn AddImageToAtlas(
    atlas: *Atlas,
    allocator: std.mem.Allocator,
    path: []const u8,
) !void {

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();

    const read_buf = try allocator.alloc(u8, file_size);
    defer allocator.free(read_buf);

    _ = try file.readAll(read_buf);

    // ---- load image ----
    var img = try zigimg.Image.fromFilePath(
        allocator,
        path,
        read_buf,
    );
    defer img.deinit(allocator);

    // Force RGBA8 (4 × u8 = 32 bits)
    try img.convert(allocator, .rgba32);

    const img_w: u32 = @intCast(img.width);
    const img_h: u32 = @intCast(img.height);

    // Allocate atlas pixel buffer if needed
    if (atlas.pixels == null) {
        atlas.width = 1024;
        atlas.height = 1024;
        atlas.pixels = try allocator.alloc(u8, atlas.width * atlas.height * 4);
        @memset(atlas.pixels.?, 0);
    }

    // Simple row-based packing
    if (atlas.cursor_x + img_w > atlas.width) {
        atlas.cursor_x = 0;
        atlas.cursor_y += atlas.row_h;
        atlas.row_h = 0;
    }

    if (atlas.cursor_y + img_h > atlas.height)
        return error.AtlasFull;

    const src_pixels = img.pixels.rgba32;
    const src_bytes = std.mem.sliceAsBytes(src_pixels);

    // Copy rows
    for (0..img_h) |row| {
        const dst = ((atlas.cursor_y + row) * atlas.width + atlas.cursor_x) * 4;
        const src = row * img_w * 4;

        @memcpy(
            atlas.pixels.?[dst .. dst + img_w * 4],
            src_bytes[src .. src + img_w * 4],
        );
    }

    atlas.row_h = @max(atlas.row_h, img_h);
    atlas.cursor_x += img_w;
}

pub fn main() !void {
    
    // Window Creation
    var game_window = try sdl.Window.init(800, 600);
    defer game_window.deinit();
    
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Core Creation
    var core = try core_mod.Core.init(true, allocator, &game_window);
    defer core.deinit(allocator);
    
    // Swapchain creation
    var sc = try swapchain_mod.Swapchain.init(allocator, &core , &game_window, .{.vsync = false}, null);
    defer sc.deinit(&core, allocator, core.alloc_cb);
    
    // Renderer creation
    var renderer = try render.Renderer.init(allocator, &core, &sc);
    defer renderer.deinit(allocator, &core);

    // Atlas Manager
    var atlas_manager = AtlasManager {
        .atlas_list = try std.ArrayList(Atlas).initCapacity(allocator, 0) 
    };

    var test_atlas = Atlas{};
    try AddImageToAtlas(&test_atlas, allocator, "textures/Slot.ktx2");

    const test_atlas_alias = try atlas_manager.AddAtlas(allocator , test_atlas);

    // Scene Manager
    var scene_manager = SceneManager {
        .scenes = try std.ArrayList(Scene).initCapacity(allocator, 0),
        .atlas_alias_table = try std.ArrayList(AtlasAliasId_u32).initCapacity(allocator, 0),
        .scene_connection_table = try std.ArrayList(SceneId_u32).initCapacity(allocator, 0),
    };

    try scene_manager.MakeScene(
        allocator,
        &.{test_atlas_alias},
        &.{},
    );

    var sprite_draws =  try std.ArrayList(helper.SpriteDraw).initCapacity(allocator, 0);
    defer sprite_draws.deinit(allocator);

    while (!game_window.should_close){
        try renderer.DrawFrame(&core, &sc, &game_window, allocator, sprite_draws.items);
        game_window.pollEvents(&renderer);
    }

}


pub fn PushSprite(sprites: *std.ArrayList(helper.SpriteDraw), sprite: helper.SpriteDraw) !void{
    try sprites.append(sprite);
}
