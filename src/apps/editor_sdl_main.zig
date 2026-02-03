const std = @import("std");
const utils = @import("utils");
const engine = @import("engine");
const zigimg = @import("zigimg");
const core_mod = engine.core;
const swapchain_mod = engine.swapchain;
const render = engine.renderer;
const helper = engine.helper;
const text = engine.textures;
const input = engine.input;
const c = engine.c;
const print = std.debug.print;
const sdl = engine.sdl;
const math = utils.math;
const algo = utils.algo;
const notify = utils.notify;
const atlas_mod = utils.atlas;
const lua_mod = engine.lua;
//const lua = lua_mod.lua;
const zlua = @import("zlua");
const Lua = zlua.Lua;

// Opaque = 0
// Alpha = 1
// UI = 2

// INVARIANTS:
// 1. atlases.json is sorted by id
// 2. atlas_list is always sorted by id
// 3. IDs are stable and never renumbered
// 4. Editor never invents IDs
fn MoveSprite(lua: *Lua) i32 {
    const a = lua.toNumber(1) catch 0;
    const b = lua.toNumber(2) catch 0;
    lua.pushNumber(a + b);
    return 1;
}

// ****************************************** CAMERA ************************************
pub const Camera = struct {
    pos: math.Vec2 = math.Vec2.ZERO,
    view_proj: math.Mat4 = math.Mat4.IDENTITY,

    pub fn Update(self: *Camera, screen_w: f32, screen_h: f32) void {

        const proj = math.Ortho(0.0, screen_w, 0.0, screen_h);

        const view = math.Mat4.TranslateWorld(proj , .{
            .x = -self.pos.x,
            .y = -self.pos.y,
            .z = 0,
        });

        self.view_proj = view;

    }

};


// ****************************************** ATLAS MANAGER **********************************


pub const AtlasManager = struct {

    atlas_list: std.ArrayList(atlas_mod.AtlasAsset),
    metadata_dirty: bool = true,
    manifest: ?atlas_mod.ParsedManifest = null, 

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
        self.manifest.?.deinit(allocator);
        self.manifest = null;
        self.atlas_list.deinit(allocator);

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




// ****************************************** MAIN *******************************************


pub fn main() !void {
    
    // Window Creation
    var game_window = try sdl.Window.init(800, 600);
    defer game_window.deinit();

    // Editor Input
    var editor_input = input.EditorIntent{
        .drag_speed = 0.05,
    };
    
    // Camera 
    var camera = Camera{};
   
    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    
    // Lua
    var lua = try Lua.init(allocator);
    defer lua.deinit();

    lua.openLibs();

    lua.pushInteger(42);
    std.debug.print("{}\n", .{try lua.toInteger(1)});
    try lua.doString("print('Lua is alive')");

    lua.pushFunction(zlua.wrap(MoveSprite));
    lua.setGlobal("move_sprite");
    // Core Creation
    var core = try core_mod.Core.init(true, allocator, &game_window);
    defer core.deinit(allocator);
    
    // Swapchain creation
    var sc = try swapchain_mod.Swapchain.init(allocator, &core , &game_window, .{.vsync = false}, null);
    defer sc.deinit(&core, allocator, core.alloc_cb);
    
    // Renderer creation
    var renderer = try render.Renderer.init(allocator, &core, &sc, &game_window);
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

    const slot_uv = try atlas_mod.GetImageFromAtlas(0, "new_slot", allocator);

    if (slot_uv != null) {
        std.log.info("Found the slot", .{});
        allocator.free(slot_uv.?.name);
    }

    const sprite_w: f32 = 400.0;
    const sprite_h: f32 = 200.0;

    const screen_w = @as(f32, @floatFromInt(game_window.screen_width));
    const screen_h = @as(f32, @floatFromInt(game_window.screen_height));

    const center_x: f32 = (screen_w - sprite_w) * 0.5;
    const center_y: f32 = (screen_h - sprite_h) * 0.5;

    var slot_sprite_draw = helper.SpriteDraw{
        .uv_min = slot_uv.?.uv_min,
        .uv_max = slot_uv.?.uv_max,
        .sprite_pos   = .{ center_x, center_y},        // world position (your choice)
        .sprite_scale = .{ 300.0 , 200.0 },// world size (or whatever units you use)
        .sprite_rotation = .{1.0, 0.0}, // cos=1, sin=0 (no rotation)
        .tint = .{ 1, 1, 1, 1 },   // no tint
        .atlas_id = 0,
    };

    lua.pushLightUserdata(&slot_sprite_draw);
    lua.setGlobal("test");

    const slot_sprite_draw_s = helper.SpriteDraw{
        .uv_min = slot_uv.?.uv_min,
        .uv_max = slot_uv.?.uv_max,
        .sprite_pos   = .{ center_x + 300, center_y},        // world position (your choice)
        .sprite_scale = .{ 300.0 , 200.0 },// world size (or whatever units you use)
        .sprite_rotation = .{1.0, 0.0}, // cos=1, sin=0 (no rotation)
        .tint = .{ 1, 1, 1, 1 },   // no tint
        .atlas_id = 0,
    };
    try sprite_draws.append(allocator, slot_sprite_draw);
    try sprite_draws.append(allocator, slot_sprite_draw_s);

    while (!game_window.should_close){
        
        game_window.pollEvents(&renderer);
        input.BuildEditorIntent(&editor_input, game_window.raw_input);
        camera.pos = math.Vec2.Add(camera.pos , editor_input.drag_delta);
        camera.Update(
            @floatFromInt(game_window.screen_width), 
            @floatFromInt(game_window.screen_height)
        );
        _ = try atlas_notifier.poll();

        if (atlas_manager.metadata_dirty){
            std.log.info("meta data is dirty", .{});

            atlas_manager.metadata_dirty = false;

            atlas_manager.manifest = try atlas_mod.ReadManifest(allocator);

            try atlas_manager.ApplyMetadata(
                &renderer,
                &core,
                atlas_manager.manifest.?.parsed.value.atlases,
                allocator,
            );

        }

        try renderer.DrawFrame(
            &core, 
            &sc, 
            &game_window, 
            allocator, 
            sprite_draws.items,
            camera.view_proj,
        );

    }

}



