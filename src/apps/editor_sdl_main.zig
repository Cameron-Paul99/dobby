const std = @import("std");
const utils = @import("utils");
const engine = @import("engine");
const zigimg = @import("zigimg");
const g_api = @import("game_api");
const tui = @import("editor_tui_main.zig");
const core_mod = engine.core;
const swapchain_mod = engine.swapchain;
const render = engine.renderer;
const helper = engine.helper;
const text = engine.textures;
const input = engine.input;
const c = engine.c;
const Transform2D = g_api.Transform2D;
const PhysicsAPI = g_api.PhysicsAPI;
const print = std.debug.print;
const sdl = engine.sdl;
const math = utils.math;
const algo = utils.algo;
const notify = utils.notify;
const atlas_mod = utils.atlas;
const two_bit = utils.two_bit;
const time = utils.time;
const Camera = utils.camera;
const Mouse = utils.mouse;
const RadiusRender = helper.RadiusRender;
const SceneManager = utils.scene_manager;
const Physics = utils.physics;
const GameInput = input.KeyBoardGameInput;

const MAX_ENTITIES: u32 = 100_000;
const MAX_GAME_MEMORY = 1 * 1024 * 1024; // 1 MB

var g_active_ctx: *ProjectContext = undefined;
var physics_ctx: *Physics = undefined;

const GameInitFn   = *const fn (*g_api.GameAPI, *g_api.GameMemory, *g_api.PhysicsAPI) callconv(.c) void;
const GameUpdateFn = *const fn (f64) callconv(.c) void;
const GameInputPressedFn = *const fn (u8) callconv(.c) void;
const GameInputDownFn = *const fn (u8) callconv(.c) void;
const GameInputUpFn = *const fn (u8) callconv(.c) void;


pub export fn EnableGravity(id: u32) callconv(.c) void {
    const ctx = physics_ctx;
    ctx.EnableGravity(id);
}

pub export fn AddForce(id: u32, x: f32, y: f32) callconv(.c) void {
    const ctx = physics_ctx;
    ctx.AddForce(id, x, y);
}

pub export fn AddForceX(id: u32, x:f32) callconv(.c) void {
    const ctx = physics_ctx;
    ctx.AddForceX(id, x);
}

pub export fn AddForceY(id: u32, y:f32) callconv(.c) void {
    const ctx = physics_ctx;
    ctx.AddForceY(id, y);
}

pub export fn RemoveEntity(id: u32) callconv(.c) void {
    const ctx = g_active_ctx;
    ctx.alive.Clear(id);
}

pub export fn AddEntity() callconv(.c) u32 {
    const ctx = g_active_ctx;
    const id = ctx.alive.Create() orelse unreachable;

    const entity_transform = Transform2D {};
    
    ctx.entity_transforms[id] = entity_transform;
   // std.log.info("Entity {d} is alive", .{id});
    return id;
}

pub export fn SetCameraPosition(x: f32, y: f32) callconv(.c) void {
    const ctx = g_active_ctx;
    _ = ctx;
    _ = x;
    _ = y;


}

pub export fn SetTransform(id: u32, transform: Transform2D) callconv(.c) void {
     const ctx = g_active_ctx;
     ctx.entity_transforms[id] = transform;
    

}
pub export fn AddTransform2D(id: u32, delta: Transform2D) callconv(.c) void {
    const ctx = g_active_ctx;
    var t = &ctx.entity_transforms[id];

    t.pos_x += delta.pos_x;
    t.pos_y += delta.pos_y;

    t.scale_x += delta.scale_x;
    t.scale_y += delta.scale_y;

    t.rot_x += delta.rot_x;
    t.rot_y += delta.rot_y;

    if (ctx.has_sprite.testBit(id)) {
        var sprite = &ctx.sprite_components[id];
        sprite.sprite_pos = .{ t.pos_x, t.pos_y };
        sprite.sprite_scale = .{ t.scale_x, t.scale_y };
        sprite.sprite_rotation = .{ t.rot_x, t.rot_y }; 
    }
}

pub export fn AddTransform2DPos(id: u32, dx: f32, dy: f32) callconv(.c) void {
    const ctx = g_active_ctx;
    ctx.entity_transforms[id].pos_x += dx;
    ctx.entity_transforms[id].pos_y += dy;
      if (ctx.has_sprite.testBit(id)) {
        const t = ctx.entity_transforms[id];
        var s = &ctx.sprite_components[id];
        s.sprite_pos = .{ t.pos_x, t.pos_y };
    }
}

pub export fn AddPhysics(id: u32) callconv(.c) void {

    const ctx = g_active_ctx;
    ctx.static_dirty = true;
    ctx.physics.Set(id);

}

pub export fn RemovePhysics(id: u32) callconv(.c) void {
    const ctx = g_active_ctx;
    ctx.static_dirty = true;
    ctx.physics.Clear(id);
}

pub export fn SpawnSprite(desc: *const g_api.SpriteDesc, id: u32) callconv(.c) void {
    
    const ctx = g_active_ctx;

    const slot_uv = atlas_mod.GetImageFromAtlas(0, desc.name, ctx.proj, ctx.allocator) catch |err| {
        std.log.err("GetImageFromAtlas failed: {}", .{err});
        return; // or fallback
    };

    if (slot_uv != null) {
        ctx.allocator.free(slot_uv.?.name);
    }

    const transform = ctx.entity_transforms[id];

    const sprite = helper.SpriteDraw{
        .entity = id,
        .sprite_pos = .{transform.pos_x, transform.pos_y},
        .sprite_scale = .{transform.scale_x, transform.scale_y},
        .sprite_rotation = .{transform.rot_x, transform.rot_y},
        .uv_min = slot_uv.?.uv_min,
        .uv_max = slot_uv.?.uv_max,
        .tint = desc.tint,
        .atlas_id = desc.atlas_id,
    };
    std.log.info("Spawning sprite for entity: {d}", .{id});
    ctx.has_sprite.Set(id);
    //std.log.info("Sprite name is: {s}", .{desc.name});
    ctx.sprite_components[id] = sprite;
}
pub export fn GetAllocator() callconv(.c) *anyopaque {
    return &g_active_ctx.allocator;
}

pub export fn SetSpritePos(entity: u32, x: f32, y: f32) callconv(.c) void {
    _ = entity;
    _ = x;
    _ = y;
}
fn EditorMoveEntity(
    editor_input: input.RawInput,
    select_buffer: *std.ArrayList(u32),
    camera: *Camera,
) void {

    const move_down = (editor_input.buttons_down & input.Bit(.mouse_left)) != 0;


    if (move_down and select_buffer.items.len > 0) {

        var delta = editor_input.mouse_delta;

        delta = math.Vec2.Mul(delta, 1.0 / camera.zoom);

        //std.log.info(
        //    "Raw mouse delta: {d}, {d}",
        //    .{ delta.x, delta.y }
        //);

        for (select_buffer.items) |entity_id| {

            AddTransform2DPos(entity_id, delta.x, delta.y);
        }
    }
}


// ****************************************** PROCJECT CONTEXT *******************************************
pub const ProjectContext = struct {
    proj_name: []const u8,
    proj: utils.Project,
    game_memory_buffer: []u8,
    game_memory: g_api.GameMemory = undefined,
    allocator: std.mem.Allocator,
    atlas_manager: AtlasManager,
    game_api: g_api.GameAPI = undefined,
    physics_api: g_api.PhysicsAPI = undefined,
    lib: ?std.DynLib,
    game_init: ?*const fn (*g_api.GameAPI, *g_api.GameMemory, *g_api.PhysicsAPI) callconv(.c) void,
    game_update: ?*const fn (f64) callconv(.c) void,
    game_input: GameInput,
    sprite_draws: std.ArrayList(helper.SpriteDraw),
    paused: bool = true,
    alive: two_bit,
    render_area: RadiusRender, 
    has_sprite: two_bit,
    physics: two_bit,
    static_dirty: bool = true,
    sprite_components: []helper.SpriteDraw,
    entity_transforms: []Transform2D,

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

        const buffer = try allocator.alignedAlloc(u8,@enumFromInt(6),  MAX_GAME_MEMORY, ); 
        @memset(buffer, 0);

        return .{
            .proj_name = name,
            .proj = .{
              .name = "",
              .path = "",
            },
            .game_memory_buffer = buffer,
            .game_memory = .{
                .ptr = buffer.ptr,
                .size = buffer.len,
            },
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
                .add_physics = AddPhysics,
                .remove_physics = RemovePhysics,
                .add_transform_2D = AddTransform2D,
            },
            .physics_api = g_api.PhysicsAPI{
                .enable_gravity = EnableGravity,
                .add_force = AddForce,
                .add_force_x = AddForceX,
                .add_force_y = AddForceY,
            },
            .game_init = lib.lookup(GameInitFn, "game_init"),
            .game_update = lib.lookup(GameUpdateFn, "game_update"),
            .game_input = .{
                .game_input_pressed = lib.lookup(
                    GameInputPressedFn, 
                    "game_input_pressed"),
                .game_input_down = lib.lookup(
                    GameInputDownFn,
                    "game_input_down"),
                 .game_input_up = lib.lookup(
                    GameInputDownFn,
                    "game_input_up"),
            },
            .sprite_draws = try std.ArrayList(helper.SpriteDraw)
                .initCapacity(allocator, 0),
            .sprite_components = try allocator.alloc(helper.SpriteDraw, MAX_ENTITIES),
            .entity_transforms = try allocator.alloc(Transform2D, MAX_ENTITIES), 
            .alive = try two_bit.init(MAX_ENTITIES, allocator), 
            .render_area = try RadiusRender.init(MAX_ENTITIES, allocator),
            .has_sprite = try two_bit.init(MAX_ENTITIES, allocator),
            .physics = try two_bit.init(MAX_ENTITIES, allocator),
        };

    }

    pub fn ReloadProjectScripts(self: *ProjectContext) !void {

      self.alive.clearAll();
      self.has_sprite.clearAll();
      self.physics.clearAll();
      self.static_dirty = true; 

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

        self.game_input.game_input_pressed = self.lib.?.lookup(
            GameInputPressedFn, 
            "game_input_pressed");

        self.game_input.game_input_down = self.lib.?.lookup(
            GameInputDownFn,
            "game_input_down");

        self.game_input.game_input_up = self.lib.?.lookup(
            GameInputUpFn,
            "game_input_up");

        if (self.game_init == null) return error.MissingGameInit;
        if (self.game_update == null) return error.MissingGameUpdate;
        if (self.game_input.game_input_down == null) return error.MissingGameInputDown;
        if (self.game_input.game_input_pressed == null) return error.MissingGameInputPressed;
        if (self.game_input.game_input_up == null) return error.MissingGameInputUp;

        self.game_init.?(&self.game_api, &self.game_memory, &self.physics_api);

    }

    pub fn deinit(self: *ProjectContext) void {
        self.atlas_manager.deinit(self.allocator);
        self.sprite_draws.deinit(self.allocator);
        self.allocator.free(self.sprite_components);
        self.allocator.free(self.entity_transforms);
        self.allocator.free(self.game_memory_buffer);
        self.alive.deinit();
        self.render_area.deinit();
        self.has_sprite.deinit();
        self.physics.deinit();
        self.lib.?.close();
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

    var t = time.Start();
    var g_t = time.Start();

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

    // Editor Input
    var editor_input = input.EditorIntent{
        .drag_speed = 1.0,
    };

    // Game Input
    //var game_input = input.
    var gameMode = false;
    
    // Camera 
    var cam = Camera.init(@floatFromInt(game_window.screen_width),@floatFromInt(game_window.screen_height)); 

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

    // Physics
    var physics = try Physics.init(MAX_ENTITIES, allocator);
    defer physics.deinit(allocator);

    physics_ctx = &physics;

    // Scripts Notifier
    var scripts_notifier = try notify.Inotify.init(proj_scripts_path, allocator);
    defer scripts_notifier.deinit(allocator);

    // Project context
    var project_context = try ProjectContext.init(allocator, proj.parsed.value.name);
    defer project_context.deinit();

    g_active_ctx = &project_context;
    project_context.game_api.user_data = g_active_ctx;

    project_context.proj = proj.parsed.value;

    project_context.alive.clearAll();
    project_context.physics.clearAll();
    project_context.has_sprite.clearAll();

    RebuildScripts(allocator, proj_scripts_path, &project_context) catch |err| {
        std.log.err("Script rebuild failed: {}", .{err});
    };

    var reload: bool = false;

    t.HardRestart();
    g_t.HardRestart();
// ****************************************** Rendering START *******************************************

    while (!game_window.should_close){
        
        game_window.pollEvents(&renderer, &project_context.game_input);

        input.BuildEditorIntent( 
            &editor_input,
            &gameMode,
            game_window.raw_input,
            &t,
            &g_t,
            &reload,
        );
        if (reload){
            reload = false;
            RebuildScripts(allocator, proj_scripts_path, &project_context) catch |err| {
                std.log.err("Script rebuild failed: {}", .{err});
            };
        }

        t.Runnin();
        if (gameMode){
            g_t.Runnin();
            if (!game_window.gameMode) game_window.gameMode = true;
        }
        tui.BeginUI();
        try tui.UpdateCameraUI(cam.pos.x, cam.pos.y, cam.zoom);
        try tui.UpdateMouseUI(mouse.world_pos.x, mouse.world_pos.y);
        try tui.FlushUI();
// ****************************************** CAMERA UPDATING *******************************************
        cam.UpdateCameraAttributes(
            editor_input.zoom, 
            editor_input.drag_delta
        );

        cam.UpdateViewProj(
            @floatFromInt(game_window.screen_width),
            @floatFromInt(game_window.screen_height),
        );

// ****************************************** MOUSE UPDATING *******************************************
        mouse.Update(
            game_window.raw_input.mouse_pos,
            &cam,
            @floatFromInt(game_window.screen_width),
            @floatFromInt(game_window.screen_height),
        );

// ****************************************** PROJECT UPDATING *******************************************
        if (project_context.game_update) |game_update| {

            if (!t.pause and !gameMode) {
                game_update(t.time_sec);
            }else if (!g_t.pause) {
                game_update(g_t.time_sec);
            }
            
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

            project_context.atlas_manager.manifest = try atlas_mod.ReadManifest(proj.parsed.value, allocator);

            try project_context.atlas_manager.ApplyMetadata(
                &renderer,
                &core,
                project_context.atlas_manager.manifest.?.parsed.value.atlases,
                allocator,
            );

        }
        
        if (!gameMode){
            input.DeleteEditorIntent(
                &project_context.alive,
                &project_context.has_sprite,
                &project_context.physics,
                &select_buffer,
                &project_context.static_dirty,
                game_window.raw_input,
            );

            try input.BuildEditorSelectIntent(
                project_context.sprite_components,
                mouse.world_pos,
                &project_context.alive,
                &project_context.has_sprite,
                &select_buffer,
                game_window.raw_input,
                allocator,
            );

            EditorMoveEntity(
                game_window.raw_input,
                &select_buffer,
                &cam,
            );
        }

        project_context.sprite_draws.clearRetainingCapacity();

        project_context.has_sprite.forEachBitSet(
            struct {
                list: *std.ArrayList(helper.SpriteDraw),
                comps: []helper.SpriteDraw,
                alive: *const two_bit,
                allocator: std.mem.Allocator,

                pub fn call(f: @This(), entity: u32) void {
                    if (!f.alive.testBit(entity)) return;
                    f.list.append(f.allocator, f.comps[entity]) catch unreachable;
                }
            }{
                .list = &project_context.sprite_draws,
                .comps = project_context.sprite_components,
                .alive = &project_context.alive,
                .allocator = allocator
            }
        );

        if (!t.pause and !gameMode){
            project_context.physics.forEachBitSet(
                struct {
                    alive: *const two_bit,
                    entity_transforms: []Transform2D,
                    sprites: []helper.SpriteDraw,
                    has_sprite: *const two_bit,
                    physics: *Physics,
                    pub fn call(f: @This(), entity: u32) void {
                        if (!f.alive.testBit(entity)) return;
                        f.physics.Step(entity, &f.entity_transforms[entity]);
                        if (!f.has_sprite.testBit(entity)) return;
                        f.sprites[entity].sprite_pos = .{
                            f.entity_transforms[entity].pos_x, 
                            f.entity_transforms[entity].pos_y
                        };
                    }
                }{
                    .entity_transforms = project_context.entity_transforms,
                    .alive = &project_context.alive,
                    .sprites = project_context.sprite_components,
                    .has_sprite = &project_context.has_sprite,
                    .physics = &physics,
                }
            );
        }

        if (gameMode and !g_t.pause) {
            project_context.physics.forEachBitSet(
                struct {
                    alive: *const two_bit,
                    entity_transforms: []Transform2D,
                    sprites: []helper.SpriteDraw,
                    has_sprite: *const two_bit,
                    physics: *Physics,
                    pub fn call(f: @This(), entity: u32) void {
                        if (!f.alive.testBit(entity)) return;
                        f.physics.Step(entity, &f.entity_transforms[entity]);
                        if (!f.has_sprite.testBit(entity)) return;
                        f.sprites[entity].sprite_pos = .{
                            f.entity_transforms[entity].pos_x, 
                            f.entity_transforms[entity].pos_y
                        };
                    }
                }{
                    .entity_transforms = project_context.entity_transforms,
                    .alive = &project_context.alive,
                    .sprites = project_context.sprite_components,
                    .has_sprite = &project_context.has_sprite,
                    .physics = &physics,
                }
            );
        }

      
// ****************************************** RENDERING *******************************************

        try renderer.DrawFrame(
            &core, 
            &sc, 
            &game_window, 
            allocator,
            project_context.sprite_draws.items,
            cam.view_proj,
        );

    }

}




