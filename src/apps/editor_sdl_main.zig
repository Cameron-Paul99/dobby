const std = @import("std");
const utils = @import("utils");
const engine = @import("engine");
const zigimg = @import("zigimg");
const g_api = @import("game_api");
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
const two_bit = utils.two_bit;


// Opaque = 0
// Alpha = 1
// UI = 2

// INVARIANTS:
// 1. atlases.json is sorted by id
// 2. atlas_list is always sorted by id
// 3. IDs are stable and never renumbered
// 4. Editor never invents IDs
//
const MAX_ENTITIES: u32 = 100_000;

var g_active_ctx: *ProjectContext = undefined;
const GameInitFn   = *const fn (*g_api.GameAPI) callconv(.c) void;
const GameUpdateFn = *const fn (f64) callconv(.c) void;

pub export fn RemoveEntity(id: u32) callconv(.c) void {
    const ctx = g_active_ctx;
    ctx.alive.Clear(id);
}

pub export fn AddEntity() callconv(.c) u32 {
    const ctx = g_active_ctx;
    return ctx.alive.Create() orelse unreachable;
}

pub export fn SpawnSprite(desc: *const g_api.SpriteDesc) callconv(.c) u32 {
    
    const ctx = g_active_ctx;
    const id = ctx.alive.Create() orelse unreachable;

    const sprite = helper.SpriteDraw{
        .entity = id,
        .sprite_pos = desc.sprite_pos,
        .sprite_scale = desc.sprite_scale,
        .sprite_rotation = desc.sprite_rotation,
        .uv_min = desc.uv_min,
        .uv_max = desc.uv_max,
        .tint = desc.tint,
        .atlas_id = desc.atlas_id,
    };
    ctx.has_sprite.Set(id);
    ctx.sprite_components[id] = sprite;

    return id; 
}
pub export fn GetAllocator() callconv(.c) *anyopaque {
    return &g_active_ctx.allocator;
}

pub export fn SetSpritePos(entity: u32, x: f32, y: f32) callconv(.c) void {
    _ = entity;
    _ = x;
    _ = y;
}

pub const ProjectContext = struct {
    proj_name: []const u8,
    allocator: std.mem.Allocator,
    scene_manager: SceneManager,
    atlas_manager: AtlasManager,
    game_api: g_api.GameAPI = undefined,
    lib: ?std.DynLib,
    game_init: ?*const fn (*g_api.GameAPI) callconv(.c) void,
    game_update: ?*const fn (f64) callconv(.c) void,
    sprite_draws: std.ArrayList(helper.SpriteDraw),
    alive: two_bit,
    has_sprite: two_bit,
    sprite_components: []helper.SpriteDraw,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
    ) !ProjectContext{

        const path = try std.fmt.allocPrint(
            allocator,
            "projects/{s}/assets/src/scripts/zig-out/lib/lib{s}_game.so",
            .{name, name},
        );
        defer allocator.free(path);
        var lib = try std.DynLib.open(path);

        return .{
            .proj_name = name,
            .allocator = allocator,
            .atlas_manager = .{
                .atlas_list = try std.ArrayList(atlas_mod.AtlasAsset)
                    .initCapacity(allocator, 0),
            },
            .lib = lib,
            .game_api = g_api.GameAPI {
                .user_data = null,
                .add_entity = AddEntity,
                .remove_enity = RemoveEntity,
                .spawn_sprite = SpawnSprite,
                .set_sprite_pos = SetSpritePos,
                .get_allocator = GetAllocator,
            },
            .game_init = lib.lookup(GameInitFn, "game_init"),
            .game_update = lib.lookup(GameUpdateFn, "game_update"),
            .scene_manager = .{
                .scenes = try std.ArrayList(Scene).initCapacity(allocator, 0),
                .atlas_alias_table = try std.ArrayList(atlas_mod.AtlasAliasId_u32)
                    .initCapacity(allocator, 0),
                .scene_connection_table = try std.ArrayList(SceneId_u32)
                    .initCapacity(allocator, 0),
            },
            .sprite_draws = try std.ArrayList(helper.SpriteDraw)
                .initCapacity(allocator, 0),
            .sprite_components = try allocator.alloc(helper.SpriteDraw, MAX_ENTITIES),
            .alive = try two_bit.init(MAX_ENTITIES, allocator), 
            .has_sprite = try two_bit.init(MAX_ENTITIES, allocator),  
        };

    }

    pub fn ReloadProjectScripts(self: *ProjectContext) !void {
        self.alive.clearAll();
        const path = try std.fmt.allocPrint(
            self.allocator,
            "projects/{s}/assets/src/scripts/zig-out/lib/lib{s}_game.so",
            .{self.proj_name, self.proj_name},
        );
        defer self.allocator.free(path);
    
        if (self.lib) |*old| old.close();
        self.lib = null;
        self.game_init = null;
        self.game_update = null;

        self.lib = try std.DynLib.open(path);

        self.game_init = self.lib.?.lookup(GameInitFn, "game_init");
        self.game_update = self.lib.?.lookup(GameUpdateFn, "game_update");

        if (self.game_init == null) return error.MissingGameInit;
        if (self.game_update == null) return error.MissingGameUpdate;

        self.game_init.?(&self.game_api);

    }

    pub fn deinit(self: *ProjectContext) void {
        self.atlas_manager.deinit(self.allocator);
        self.scene_manager.deinit(self.allocator);
        self.sprite_draws.deinit(self.allocator);
        self.allocator.free(self.sprite_components);
        try self.alive.deinit();
        try self.has_sprite.deinit();
        self.lib.?.close();
    }
};



// ****************************************** CAMERA ************************************
pub const Camera = struct {
    pos: math.Vec2 = math.Vec2.ZERO,
    zoom: f32 = 1.0,
    view_proj: math.Mat4 = math.Mat4.IDENTITY,

pub fn Update(self: *Camera, screen_w: f32, screen_h: f32) void { 

    const half_w = ( screen_w * 0.5 ) / self.zoom; 
    const half_h = ( screen_h * 0.5 ) / self.zoom; 

    const left = self.pos.x - half_w; 
    const right = self.pos.x + half_w; 

    const bottom = self.pos.y - half_h; 
    const top = self.pos.y + half_h; 
    self.view_proj = math.Ortho(left, right, bottom, top); 
}

};

// ****************************************** MOUSE ************************************
pub const Mouse = struct {
    world_pos: math.Vec2 = math.Vec2.ZERO,
    sdl_pos: math.Vec2 = math.Vec2.ZERO,

pub fn Update(
    self: *Mouse,
    cam: *const Camera,
    screen_w: f32,
    screen_h: f32,
) void {

    const half_w = (screen_w * 0.5) / cam.zoom;
    const half_h = (screen_h * 0.5) / cam.zoom;

    const left   = cam.pos.x - half_w;
    const bottom = cam.pos.y - half_h;

    self.world_pos = .{
        .x = left + (self.sdl_pos.x / cam.zoom),
        .y = bottom + (self.sdl_pos.y / cam.zoom),
    };
}

};

// ****************************************** ATLAS MANAGER **********************************


pub const AtlasManager = struct {

    atlas_list: std.ArrayList(atlas_mod.AtlasAsset),
    metadata_dirty: bool = false,
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

        if (self.manifest) |*manifest| {
            manifest.deinit(allocator);
        }
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

fn RebuildScripts(
    allocator: std.mem.Allocator, 
    cwd: []const u8,
    proj_ctx: *ProjectContext) !void {

    var argv = [_][]const u8{
        "zig",
        "build",
    };

    var child = std.process.Child.init(&argv, allocator);
    child.cwd = cwd;
    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Inherit;
    child.stderr_behavior = .Inherit;

    const term = try child.spawnAndWait();

    if (term != .Exited or term.Exited != 0) {
        return error.BuildFailed;
    }

    std.log.info("Scripts rebuilt", .{});

    try proj_ctx.ReloadProjectScripts();

}



// ****************************************** MAIN *******************************************


pub fn main() !void {

    const start_time = std.time.nanoTimestamp();

    // Allocator
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Window Creation
    var game_window = try sdl.Window.init(1920, 1080);
    defer game_window.deinit();

    var drawable_w: c_int = 0;
    var drawable_h: c_int = 0;
    _ = c.SDL_GetWindowSizeInPixels(game_window.window, &drawable_w, &drawable_h);
    game_window.screen_width = drawable_w;
    game_window.screen_height = drawable_h;

    const w: f32 = @floatFromInt(game_window.screen_width);
    const h: f32 =  @floatFromInt(game_window.screen_height);

    // Editor Input
    var editor_input = input.EditorIntent{
        .drag_speed = 1.0,
    };
    
    // Camera 
    var camera = Camera{
        .pos = math.Vec2.Make(w * 0.5, h * 0.5),
    };
    camera.pos.x /= camera.zoom;
    camera.pos.y /= camera.zoom;

    // Mouse
    var mouse = Mouse{};
    std.log.info("mouse world: {d},{d}", .{mouse.world_pos.x, mouse.world_pos.y});

    // Select Buffer
    var select_buffer = try std.ArrayList(u32).initCapacity(allocator, 0);
    defer select_buffer.deinit(allocator);

    // Project
    var proj = try utils.LoadProject(allocator);
    defer proj.deinit(allocator);

    std.log.info("Opening project {s}", .{proj.parsed.value.name});

    // Core Creation
    var core = try core_mod.Core.init(true, allocator, &game_window);
    defer core.deinit(allocator);
    
    // Swapchain creation
    var sc = try swapchain_mod.Swapchain.init(allocator, &core , &game_window, .{.vsync = false}, null);
    defer sc.deinit(&core, allocator, core.alloc_cb);
    
    // Renderer creation
    var renderer = try render.Renderer.init(allocator, &core, &sc, &game_window);
    defer renderer.deinit(allocator, &core);

    // Atlas Path Creation
    const atlas_path = try std.fmt.allocPrint(
        allocator,
        "projects/{s}/assets/cooked/atlases/",
        .{ proj.parsed.value.name},
    );
    defer allocator.free(atlas_path); 

    const proj_atlas_path = try allocator.dupeZ(u8 , atlas_path);
    defer allocator.free(proj_atlas_path);

    // Atlas Notifier
    var atlas_notifier = try notify.Inotify.init(proj_atlas_path, allocator);
    defer atlas_notifier.deinit(allocator);

    // Scripts path
    const scripts_path = try std.fmt.allocPrint(
        allocator,
        "projects/{s}/assets/src/scripts/",
        .{ proj.parsed.value.name },
    );
    defer allocator.free(scripts_path);

    const proj_scripts_path = try allocator.dupeZ(u8, scripts_path);
    defer allocator.free(proj_scripts_path);

    // Scripts Notifier
    var scripts_notifier = try notify.Inotify.init(proj_scripts_path, allocator);
    defer scripts_notifier.deinit(allocator);

    // Project context
    var project_context = try ProjectContext.init(allocator, proj.parsed.value.name);
    defer project_context.deinit();

    g_active_ctx = &project_context;
    project_context.game_api.user_data = g_active_ctx;
    project_context.alive.clearAll();
    RebuildScripts(allocator, proj_scripts_path, &project_context) catch |err| {
        std.log.err("Script rebuild failed: {}", .{err});
    };

    if (project_context.game_init) |game_init|{
        game_init(&project_context.game_api);
    }

//    const slot_sprite_draw = helper.SpriteDraw{
//        .entity = 0,
//        .uv_min = .{0.0, 0.0},
//        .uv_max = .{1.0, 1.0},
//        .sprite_pos   = .{0.0, 0.0},        // world position (your choice)
//        .sprite_scale = .{ 100, 50.0 },// world size (or whatever units you use)
//        .sprite_rotation = .{1.0, 0.0}, // cos=1, sin=0 (no rotation)
//        .tint = .{ 1, 1, 1, 1 },   // no tint
//        .atlas_id = 0,
//    };
//    try project_context.sprite_draws.append(allocator, slot_sprite_draw);
//
    while (!game_window.should_close){

        const now = std.time.nanoTimestamp();
        const time_sec = @as(f64, @floatFromInt(now - start_time)) / 1_000_000_000.0;
        
        game_window.pollEvents(&renderer);

        input.BuildEditorIntent(
            &project_context.sprite_draws, 
            &editor_input, 
            game_window.raw_input,
            mouse.world_pos, // This will be updated below
        );

        camera.zoom = editor_input.zoom;
        camera.pos = math.Vec2.Add(camera.pos, math.Vec2.Make(
            editor_input.drag_delta.x / camera.zoom,
            editor_input.drag_delta.y / camera.zoom,
        ));
        camera.Update(
            @floatFromInt(game_window.screen_width),
            @floatFromInt(game_window.screen_height),
        );

        mouse.sdl_pos = game_window.raw_input.mouse_pos;

        mouse.Update(
            &camera,
            @floatFromInt(game_window.screen_width),
            @floatFromInt(game_window.screen_height),
        );


        if (project_context.game_update) |game_update| {
            game_update(time_sec);
        }

        const scripts_bytes = try scripts_notifier.poll();
        if (scripts_bytes > 0){
            std.log.info("Rebuilding scripts", .{});
            project_context.sprite_draws.clearRetainingCapacity();
            RebuildScripts(allocator, proj_scripts_path, &project_context) catch |err| {
                std.log.err("Script rebuild failed: {}", .{err});
            };
        }

        const atlas_bytes = try atlas_notifier.poll();
        if (atlas_bytes > 0) {
            project_context.atlas_manager.metadata_dirty = true;
        }

        if (project_context.atlas_manager.metadata_dirty){
            std.log.info("meta data is dirty", .{});

            project_context.atlas_manager.metadata_dirty = false;

            project_context.atlas_manager.manifest = try atlas_mod.ReadManifest(
                proj.parsed.value, 
                allocator);

            try project_context.atlas_manager.ApplyMetadata(
                &renderer,
                &core,
                project_context.atlas_manager.manifest.?.parsed.value.atlases,
                allocator,
            );

        }
        project_context.sprite_draws.clearRetainingCapacity();

        project_context.has_sprite.forEachBitSet(
        struct {
            ctx: *ProjectContext,
            allocator: std.mem.Allocator,

            pub fn call(self: @This(), entity: u32) void {
                    if (!self.ctx.alive.testBit(entity)) return;

                    const sprite = self.ctx.sprite_components[entity];
                    self.ctx.sprite_draws.append(self.allocator, sprite) catch unreachable;
                }
            }{
            .ctx = &project_context,
            .allocator = allocator,
            }
        );

        input.DeleteEditorIntent(
            &project_context.alive,
            &project_context.has_sprite,
            &select_buffer,
            game_window.raw_input,
        );

        try input.BuildEditorSelectIntent(
            &project_context.sprite_draws,
            mouse.world_pos,
            &select_buffer,
            game_window.raw_input,
            allocator,
        );



        try renderer.DrawFrame(
            &core, 
            &sc, 
            &game_window, 
            allocator, 
            project_context.sprite_draws.items,
            camera.view_proj,
        );

    }

}




