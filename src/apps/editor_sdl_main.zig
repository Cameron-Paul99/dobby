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
const notify = utils.notify;
const atlas_mod = utils.atlas;

// Opaque = 0
// Alpha = 1
// UI = 2

// INVARIANTS:
// 1. atlases.json is sorted by id
// 2. atlas_list is always sorted by id
// 3. IDs are stable and never renumbered
// 4. Editor never invents IDs



// ****************************************** ATLAS MANAGER **********************************


pub const AtlasManager = struct {

    atlas_list: std.ArrayList(atlas_mod.AtlasAsset),
    metadata_dirty: bool = true,
    manifest: ?std.json.Parsed(atlas_mod.Manifest) = null, 

    pub fn ApplyMetadata(
        self: *AtlasManager,
        renderer: *render.Renderer,
        core: *core_mod.Core,
        desired: []const atlas_mod.AtlasEntry,
        allocator: std.mem.Allocator,
    ) !void {
        var i: usize = 0; // current
        var j: usize = 0; // desired

        while (i < self.atlas_list.items.len or j < desired.len) {

            // DELETE
            if (i < self.atlas_list.items.len and (j >= desired.len or self.atlas_list.items[i].id < desired[j].id))
            {
                self.RemoveAtlas(i, allocator);
                continue; // current shifts
            }

            // ADD
            if (j < desired.len and (i >= self.atlas_list.items.len or desired[j].id < self.atlas_list.items[i].id))
            {
                _ = try self.AddAtlas(renderer, core , desired[j], allocator);
                j += 1;
                continue;
            }

            // SAME ID → UPDATE / NO-OP
            if (self.atlas_list.items[i].id == desired[j].id) {
                if (self.atlas_list.items[i].version_hash != desired[j].rev) {
                    self.atlas_list.items[i].version_hash = desired[j].rev;
                }
                i += 1;
                j += 1;
            }
        }
    }

    fn AddAtlas(
        self: *AtlasManager,
        renderer: *render.Renderer,
        core: *core_mod.Core,
        meta: atlas_mod.AtlasEntry,
        allocator: std.mem.Allocator) !atlas_mod.AtlasAliasId_u32 {

        const owned_path = try allocator.dupe(u8, meta.path);

        const atlas = atlas_mod.AtlasAsset{
            .id = meta.id,
            .path = owned_path,
            .version_hash = meta.rev,
        };

        try self.atlas_list.append(allocator, atlas);

        try renderer.AddAtlasGPU(core, atlas, allocator);

        return @intCast(meta.id);
    }


    fn RemoveAtlas(
        self: *AtlasManager,
        index: usize,
        allocator: std.mem.Allocator,
    ) void{
        allocator.free(self.atlas_list.items[index].path);
        _ = self.atlas_list.orderedRemove(index);
    }

    pub fn deinit(self: *AtlasManager, allocator: std.mem.Allocator) void{

        if (self.manifest) |*m| m.deinit();
        defer self.atlas_list.deinit(allocator);

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
    atlas_alias_table: std.ArrayList(atlas_mod.AtlasAliasId_u32),
    scene_connection_table: std.ArrayList(SceneId_u32),

    pub fn MakeScene(
        self: *SceneManager, 
        allocator: std.mem.Allocator,
        alias_ids: []const atlas_mod.AtlasAliasId_u32,
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

    pub fn deinit(self: *SceneManager, allocator: std.mem.Allocator) void{
        self.scenes.deinit(allocator);
        self.atlas_alias_table.deinit(allocator);
        self.scene_connection_table.deinit(allocator);
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
        .atlas_list = try std.ArrayList(atlas_mod.AtlasAsset).initCapacity(allocator, 0) 
    };
    defer atlas_manager.deinit(allocator);
    

    var atlas_notifier = try notify.Inotify.init("assets/cooked/atlases/", allocator);
    defer atlas_notifier.deinit(allocator);

    // Scene Manager
    var scene_manager = SceneManager {
        .scenes = try std.ArrayList(Scene).initCapacity(allocator, 0),
        .atlas_alias_table = try std.ArrayList(atlas_mod.AtlasAliasId_u32).initCapacity(allocator, 0),
        .scene_connection_table = try std.ArrayList(SceneId_u32).initCapacity(allocator, 0),
    };
    defer scene_manager.deinit(allocator);

    try scene_manager.MakeScene(
        allocator,
        &.{},
        &.{},
    );

    var sprite_draws =  try std.ArrayList(helper.SpriteDraw).initCapacity(allocator, 0);
    defer sprite_draws.deinit(allocator);

    while (!game_window.should_close){

        game_window.pollEvents(&renderer);
        _ = try atlas_notifier.poll();

        if (atlas_manager.metadata_dirty){
            std.log.info("meta data is dirty", .{});

            if (atlas_manager.manifest) |*old| {
                old.deinit();
            }

            atlas_manager.metadata_dirty = false;
            atlas_manager.manifest = try atlas_mod.ReadManifest(allocator);

            try atlas_manager.ApplyMetadata(
                &renderer,
                &core,
                atlas_manager.manifest.?.value.atlases,
                allocator,
            );

        }

        try renderer.DrawFrame(
            &core, 
            &sc, 
            &game_window, 
            allocator, 
            sprite_draws.items);

    }

}


pub fn PushSprite(sprites: *std.ArrayList(helper.SpriteDraw), sprite: helper.SpriteDraw) !void{
    try sprites.append(sprite);
}
