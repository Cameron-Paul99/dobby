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

// INVARIANTS:
// 1. atlases.json is sorted by id
// 2. atlas_list is always sorted by id
// 3. IDs are stable and never renumbered
// 4. Editor never invents IDs


// *********************************** NOTIFY MANAGER ********************************

const Inotify = struct {

    fd: i32 = 0,

    pub fn init(path: []const u8) !Inotify {

        const fd = std.os.linux.inotify_init1(
            std.os.linux.IN.NONBLOCK,
        );
        if (fd < 0) return error.InotifyInitFailed;

        const wd = std.os.linux.inotify_add_watch(
            fd,
            path,
            std.os.linux.IN.MODIFY |
            std.os.linux.IN.MOVED_TO |
            std.os.linux.IN.DELETE |
            std.os.linux.IN.CREATE,
        );
        if (wd < 0) return error.InotifyWatchFailed;

        return .{ .fd = fd };

    }

    pub fn poll(self: *Inotify, atlas_manager: *AtlasManager) void {
         var buf: [4096]u8 = undefined;
         const bytes = std.os.read(self.fd, &buf) catch return;

         if (bytes > 0) {
            // Something changed → wake the system
            atlas_manager.metadata_dirty = true;
         }

    }
};

// ****************************************** ATLAS MANAGER **********************************
pub const AtlasAliasId_u32 = u32;

const AtlasAsset = struct {
    id: AtlasAliasId_u32,
    path: []const u8,
    version_hash: u64,
};

const AtlasMeta = struct {
    id: AtlasAliasId_u32,
    path: []const u8,
    version_hash: u64,
};

const AtlasMetadataFile = struct {
    version: u32,
    atlases: []AtlasMeta,
};

fn LoadAtlasMetadata(
    allocator: std.mem.Allocator,
) !std.json.Parsed(AtlasMetadataFile) {

    const data = try std.fs.cwd().readFileAlloc(
        allocator,
        "assets/cooked/atlases/atlases.json",
        1 << 20, // 1 MB cap (more than enough)
    );

    return try std.json.parseFromSlice(
        AtlasMetadataFile,
        allocator,
        data,
        .{},
    );
}

pub const AtlasManager = struct {

    atlas_list: std.ArrayList(AtlasAsset),
    metadata_dirty: bool,

    pub fn ApplyMetadata(
        self: *AtlasManager,
        desired: []const AtlasMeta,
        allocator: std.mem.Allocator,
    ) !void {
        var i: usize = 0; // current
        var j: usize = 0; // desired

        while (i < self.atlas_list.items.len or j < desired.len) {

            // DELETE
            if (i < self.atlas_list.items.len and (j >= desired.len or self.atlas_list.items[i].id < desired[j].id))
            {
                try self.RemoveAtlas(i, allocator);
                continue; // current shifts
            }

            // ADD
            if (j < desired.len and (i >= self.atlas_list.items.len or desired[j].id < self.atlas_list.items[i].id))
            {
                try self.AddAtlas(desired[j], allocator);
                j += 1;
                continue;
            }

            // SAME ID → UPDATE / NO-OP
            if (self.atlas_list.items[i].id == desired[j].id) {
                if (self.atlas_list.items[i].version_hash != desired[j].version_hash) {
                    self.atlas_list.items[i].version_hash = desired[j].version_hash;
                }
                i += 1;
                j += 1;
            }
        }
    }

    fn AddAtlas(
        self: *AtlasManager,
        meta: AtlasMeta,
        allocator: std.mem.Allocator) !AtlasAliasId_u32 {

        const owned_path = try allocator.dupe(u8, meta.path);

        const atlas = AtlasAsset{
            .id = meta.id,
            .path = owned_path,
            .version_hash = meta.version_hash,
        };

        try self.atlas_list.append(allocator, atlas);

        return @intCast(meta.id);
    }


    fn RemoveAtlas(
        self: *AtlasManager,
        index: AtlasAlias_u32,
        allocator: std.mem.Allocator,
    ){
        allocator.free(self.atlas_list.items[index].path);
        _ = self.atlas_list.orderedRemove(index);
    }

};

// ******************************************** SCENE MANAGER *********************************

pub const IndexRange = struct {
    offset: u32 = 0,
    count: u32 = 0,
};

pub const SceneId_u32 = u32;

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


// ****************************************** MAIN *******************************************


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
        .atlas_list = try std.ArrayList(AtlasAsset).initCapacity(allocator, 0) 
    };

    var notify = Inotify{};
    notify.init("assets/cooked/atlases/");

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
        notify.poll(&atlas_manager);

        if (atlas_manager.metadata_dirty){

            atlas_manager.metadata_dirty = false;
            var parsed = try LoadAtlasMetadata(allocator);
            defer parsed.deinit();

            try atlas_manager.ApplyMetadata(
                parsed.value.atlases,
                allocator,
            );

        }
    }

}


pub fn PushSprite(sprites: *std.ArrayList(helper.SpriteDraw), sprite: helper.SpriteDraw) !void{
    try sprites.append(sprite);
}
