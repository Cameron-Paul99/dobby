const std = @import("std");
const utils = @import("utils");
const engine = @import("engine");
const zigimg = @import("zigimg");
const g_api = @import("game_api");
const tui = @import("tui.zig");
const Bridge = @import("bridge.zig");
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
const Io = std.Io;

const MAX_ENTITIES: u32 = 100_000;
const MAX_GAME_MEMORY = 1 * 1024 * 1024; // 1 MB
                                         
const GameInitFn   = *const fn (
    *g_api.GameAPI, 
    *g_api.GameMemory, 
    *g_api.PhysicsAPI,
    *g_api.Camera2DAPI,
    *g_api.MouseAPI,
    *g_api.SpriteAPI) callconv(.c) void;
const GameUpdateFn = *const fn (f64) callconv(.c) void;
const GameInputPressedFn = *const fn (u8) callconv(.c) void;
const GameInputDownFn = *const fn (u8) callconv(.c) void;
const GameInputUpFn = *const fn (u8) callconv(.c) void;
const GameStartFn = *const fn () callconv(.c) void;
const GameDeinitFn = *const fn () callconv(.c) void;

const cooked_shaders_path = "projects/{s}/cooked/shaders";
const cooked_atlases_path = "projects/{s}/cooked/atlases/";
const src_textures_path = "projects/{s}/src/textures";
const src_shaders_path = "projects/{s}/src/shaders";
const src_scripts_path = "projects/{s}/src/scripts/";
const src_scripts_build_zig = "projects/{s}/src/scripts/build.zig";
const src_scripts_game_zig = "projects/{s}/src/scripts/game.zig";
const scripts_lib_path ="projects/{s}/src/scripts/zig-out/lib/lib{s}_game.so"; 

var g_gpa = std.heap.DebugAllocator(.{}){};
pub var g_allocator: std.mem.Allocator = undefined;

fn EditorMoveEntity(
    editor_input: input.RawInput,
    select_buffer: *std.ArrayList(u32),
    camera: *Camera,
) bool {
    const move_down =
        (editor_input.buttons_down & input.Bit(.mouse_left)) != 0 and
        (editor_input.buttons_pressed & input.Bit(.mouse_left)) == 0;

    if (!(move_down and select_buffer.items.len > 0)) return false;

    var delta = editor_input.mouse_delta;
    delta = math.Vec2.Mul(delta, 1.0 / camera.zoom);

    if (delta.x == 0 and delta.y == 0) return false;

    for (select_buffer.items) |entity_id| {
        Bridge.AddTransform2DPos(entity_id, delta.x, delta.y);
    }

    return true;
}
// ****************************************** PROCJECT CONTEXT *******************************************
pub const ProjectContext = struct {
    proj_name: []const u8,
    proj: utils.Project,
    io: Io,
    game_memory_buffer: []u8,
    game_memory: g_api.GameMemory = undefined,
    allocator: std.mem.Allocator,
    atlas_manager: AtlasManager,
    game_api: g_api.GameAPI = undefined,
    physics_api: g_api.PhysicsAPI = undefined,
    camera_api: g_api.Camera2DAPI = undefined,
    mouse_api: g_api.MouseAPI = undefined,
    sprite_api: g_api.SpriteAPI = undefined,
    lib: ?std.DynLib,
    game_init: ?*const fn (
        *g_api.GameAPI, 
        *g_api.GameMemory, 
        *g_api.PhysicsAPI, 
        *g_api.Camera2DAPI,
        *g_api.MouseAPI,
        *g_api.SpriteAPI) 
        callconv(.c) void,
    game_start: ?*const fn () callconv(.c) void,
    game_update: ?*const fn (f64) callconv(.c) void,
    game_input: GameInput,
    game_deinit: ?*const fn () callconv(.c) void,
    sprite_draws: std.ArrayList(helper.SpriteDraw),
    static_sprite_draws: std.ArrayList(helper.SpriteDraw), 
    sprite_storage: std.ArrayList(helper.SpriteDraw),
    paused: bool = true,
    alive: two_bit,
    render_area: RadiusRender, 
    has_sprite: two_bit,
    physics: two_bit,
    static_dirty: bool = true,
    sprite_components: []helper.SpriteSet,
    entity_transforms: []Transform2D,

    pub fn init(
        allocator: std.mem.Allocator,
        name: []const u8,
        io: Io,
    ) !ProjectContext{

        const path = try std.fmt.allocPrint(
            allocator,
            scripts_lib_path,
            .{name, name},
        );
        defer allocator.free(path);
        var lib = try std.DynLib.open(path);

        const buffer = try allocator.alignedAlloc(u8,@enumFromInt(6),  MAX_GAME_MEMORY, ); 
        @memset(buffer, 0);
        const sprite_components = try allocator.alloc(helper.SpriteSet, MAX_ENTITIES);

        for (sprite_components) |*set| {
            set.* = .{};
        }
        return .{
            .io = io,
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
                .add_entity = Bridge.AddEntity,
                .remove_entity = Bridge.RemoveEntity,
               // .get_allocator = Bridge.GetAllocator,
                .add_transform_2D = Bridge.AddTransform2D,
                .set_transform = Bridge.SetTransform,
                .alive = Bridge.Alive,
                .unalive = Bridge.UnAlive,
                .log = Bridge.HostLog,
                .alloc = Bridge.HostAlloc,
                .free = Bridge.HostFree,
            },
            .physics_api = g_api.PhysicsAPI{
                .enable_gravity = Bridge.EnableGravity,
                .add_force = Bridge.AddForce,
                .add_force_x = Bridge.AddForceX,
                .add_force_y = Bridge.AddForceY,
                .add_physics = Bridge.AddPhysics,
                .remove_physics = Bridge.RemovePhysics,
                .remove_gravity = Bridge.RemoveGravity,
            },
            .camera_api = g_api.Camera2DAPI {
                .set_camera_world_pos = Bridge.SetCameraWorldPosition,
                .move_camera_to_world_pos = Bridge.MoveCameraToWorldPosition,
                .move_camera_vertical = Bridge.MoveCameraVertical,
                .move_camera_horizontal = Bridge.MoveCameraHorizontal,
                .get_camera_world_pos = Bridge.GetCameraWorldPosition,
                .get_camera_zoom = Bridge.GetCameraZoom,
                .get_screen_dimensions = Bridge.GetScreenDimensions,
            },
            .mouse_api = g_api.MouseAPI {
                .set_mouse_world_pos = Bridge.SetMouseWorldPosition,
                .get_mouse_world_pos = Bridge.GetMouseWorldPosition,
                
            },
            .sprite_api = g_api.SpriteAPI {

                .spawn_sprite = Bridge.SpawnSprite,

                .set_sprite_world_pos = Bridge.SetSpriteWorldPos,
                .get_sprite_world_pos = Bridge.GetSpriteWorldPos,

                .set_sprite_color = Bridge.SetSpriteColor,
                .get_sprite_color = Bridge.GetSpriteColor,

                .set_entity_sprites_color = Bridge.SetEntitySpritesColor,
                .get_entity_sprites_color = Bridge.GetEntitySpritesColor,

                .set_entity_sprites_world_pos = Bridge.SetEntitySpritesWorldPos,
                .get_entity_sprites_world_pos = Bridge.GetEntitySpritesWorldPos,
                .reset_static = Bridge.ResetStatic,
                
            },
            .game_init = lib.lookup(GameInitFn, "game_init"),
            .game_start = lib.lookup(GameStartFn, "game_start"),
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
            .game_deinit = lib.lookup(GameDeinitFn, "game_deinit"),
            .sprite_draws = try std.ArrayList(helper.SpriteDraw)
                .initCapacity(allocator, 0),
            .static_sprite_draws = try std.ArrayList(helper.SpriteDraw)
                .initCapacity(allocator, 0),
            .sprite_storage = try std.ArrayList(helper.SpriteDraw)
                .initCapacity(allocator, 0),
            .sprite_components = sprite_components,
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

        self.sprite_storage.clearRetainingCapacity();
        self.sprite_draws.clearRetainingCapacity();
        self.static_sprite_draws.clearRetainingCapacity();
        for (self.sprite_components) |*set| {
            set.* = .{};
        }
        const path = try std.fmt.allocPrint(
            self.allocator,
            scripts_lib_path,
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
        self.game_start = self.lib.?.lookup(GameStartFn, "game_start");
        self.game_deinit = self.lib.?.lookup(GameStartFn, "game_deinit");

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
        if (self.game_start == null) return error.MissingGameStart;
        if (self.game_input.game_input_down == null) return error.MissingGameInputDown;
        if (self.game_input.game_input_pressed == null) return error.MissingGameInputPressed;
        if (self.game_input.game_input_up == null) return error.MissingGameInputUp;

        self.game_init.?(
            &self.game_api, 
            &self.game_memory, 
            &self.physics_api, 
            &self.camera_api,
            &self.mouse_api,
            &self.sprite_api,
        );

    }

    pub fn deinit(self: *ProjectContext) void {
        self.game_deinit.?();
        self.atlas_manager.deinit(self.allocator);
        self.sprite_draws.deinit(self.allocator);
        self.static_sprite_draws.deinit(self.allocator);
        self.sprite_storage.deinit(self.allocator);
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
    io: Io,
    cwd: []const u8,
    proj_ctx: *ProjectContext) !void {

    var argv = [_][]const u8{
        "zig",
        "build",
    };

    var child = try std.process.spawn(io, .{
        .argv = &argv,
        .stdin = .ignore,
        .stdout = .inherit,
        .stderr = .inherit,
        .cwd = .{ .path = cwd },
    });

    const term = try child.wait(io);

    if (term != .exited or term.exited != 0) {
        return error.BuildFailed;
    }

    std.log.info("Scripts rebuilt", .{});

    try proj_ctx.ReloadProjectScripts();

}

// ****************************************** MAIN *******************************************


pub fn main(init: std.process.Init) !void {

    const io = init.io;

    var t = time.Start(io);
    var g_t = time.Start(io);

    // Allocator
    g_allocator = g_gpa.allocator();
    defer _ = g_gpa.deinit();
    const allocator = g_allocator;

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
    var cam = Camera.init(
        @floatFromInt(game_window.screen_width),
        @floatFromInt(game_window.screen_height)
    ); 

    // Mouse
    var mouse = Mouse{};
    std.log.info("mouse world: {d},{d}", .{mouse.world_pos.x, mouse.world_pos.y});

    // Select Buffer
    var select_buffer = try std.ArrayList(u32).initCapacity(allocator, 0);
    defer select_buffer.deinit(allocator);

    // Project
    var proj = try utils.LoadProject(io , allocator);
    defer proj.deinit(allocator);

    std.log.info("Opening project {s}", .{proj.parsed.value.name});

    // Core Creation
    var core = try core_mod.Core.init(true, allocator, &game_window);
    defer core.deinit(allocator);
    
    // Swapchain creation
    var sc = try swapchain_mod.Swapchain.init(
        allocator, 
        &core , 
        &game_window, 
        .{.vsync = false}, 
        null
    );
    defer sc.deinit(&core, allocator, core.alloc_cb);
    
    // Renderer creation
    var renderer = try render.Renderer.init(allocator, &core, &sc, &game_window);
    defer renderer.deinit(allocator, &core);

    // Atlas Path Creation
    const atlas_path = try std.fmt.allocPrint(
        allocator,
        cooked_atlases_path,
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
        src_scripts_path,
        .{ proj.parsed.value.name },
    );
    defer allocator.free(scripts_path);

    const proj_scripts_path = try allocator.dupeZ(u8, scripts_path);
    defer allocator.free(proj_scripts_path);

    // Physics
    var physics = try Physics.init(MAX_ENTITIES, allocator);
    defer physics.deinit(allocator);

    Bridge.physics_ctx = &physics;

    // Scripts Notifier
    var scripts_notifier = try notify.Inotify.init(proj_scripts_path, allocator);
    defer scripts_notifier.deinit(allocator);

    // Project context
    var project_context = try ProjectContext.init(
        allocator, 
        proj.parsed.value.name,
        io,
    );
    defer project_context.deinit();

    Bridge.g_active_ctx = &project_context;
    project_context.game_api.user_data = Bridge.g_active_ctx;
    Bridge.cam_ctx = &cam;
    Bridge.mouse_ctx = &mouse;

    project_context.proj = proj.parsed.value;
    project_context.io = io;

    project_context.alive.clearAll();
    project_context.physics.clearAll();
    project_context.has_sprite.clearAll();

    RebuildScripts(io, proj_scripts_path, &project_context) catch |err| {
        std.log.err("Script rebuild failed: {}", .{err});
    };

    var reload: bool = false;

    t.HardRestart(io);
    g_t.HardRestart(io);
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
            io,
        );
        if (reload){
            reload = false;
            RebuildScripts(io,proj_scripts_path, &project_context) catch |err| {
                std.log.err("Script rebuild failed: {}", .{err});
            };
        }

        t.Runnin(io);
        if (gameMode){
            g_t.Runnin(io);
            if (!game_window.gameMode) {
                if (project_context.game_start) |game_start| {
                    game_start();
                }
                game_window.gameMode = true;
            }
        }else{
            if (game_window.gameMode){
                game_window.gameMode = false;
            }
        }

// ****************************************** CAMERA UPDATING *******************************************
        if (!gameMode){

            cam.UpdateCameraAttributes(
                editor_input.zoom, 
                editor_input.drag_delta
            );

        }else{

            cam.UpdateCameraAttributes(
                cam.zoom, 
                editor_input.drag_delta
            );
        }

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
            RebuildScripts(io, proj_scripts_path, &project_context) catch |err| {
                std.log.err("Script rebuild failed: {}", .{err});
            };
        }

        const atlas_bytes = try atlas_notifier.poll();
        if (atlas_bytes > 0) {
            project_context.atlas_manager.metadata_dirty = true;
            if (project_context.atlas_manager.manifest) |*m| {
                m.deinit(allocator);
            }
        }

        if (project_context.atlas_manager.metadata_dirty){
            std.log.info("meta data is dirty", .{});

            project_context.atlas_manager.metadata_dirty = false;

            project_context.atlas_manager.manifest = try atlas_mod.ReadManifest(
                io,
                proj.parsed.value, 
                allocator
            );

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
                project_context.sprite_storage.items,
                mouse.world_pos,
                &project_context.alive,
                &select_buffer,
                game_window.raw_input,
                allocator,
            );

            const moved = EditorMoveEntity(
                game_window.raw_input,
                &select_buffer,
                &cam,
            );

            if (moved) {
                project_context.static_sprite_draws.clearRetainingCapacity();
                project_context.static_dirty = true;
            }
        }
        
        project_context.sprite_draws.clearRetainingCapacity();

        project_context.has_sprite.forEachBitSet(
            struct {
                list: *std.ArrayList(helper.SpriteDraw),
                static_list: *std.ArrayList(helper.SpriteDraw),
                storage: *const std.ArrayList(helper.SpriteDraw),
                comps: []helper.SpriteSet,
                alive: *const two_bit,
                physics: *const two_bit,
                allocator: std.mem.Allocator,
                dirty: bool,

                pub fn call(f: @This(), entity: u32) void {
                    if (!f.alive.testBit(entity)) return;

                    if (f.dirty and !f.physics.testBit(entity)){
                        const set = f.comps[entity];
                        const sprites = f.storage.items[set.start .. set.start + set.count];

                        for (sprites) |*sprite| {
                            f.static_list.append(f.allocator, sprite.*) catch unreachable;
                        }
                        return;
                    }

                    if (f.physics.testBit(entity)){
                    
                        const set = f.comps[entity];
                        const sprites = f.storage.items[set.start .. set.start + set.count];

                        for (sprites) |*sprite| {
                            f.list.append(f.allocator, sprite.*) catch unreachable;
                        }
                    }
                }
            }{
                .list = &project_context.sprite_draws,
                .static_list = &project_context.static_sprite_draws,
                .storage = &project_context.sprite_storage,
                .comps = project_context.sprite_components,
                .alive = &project_context.alive,
                .physics = &project_context.physics,
                .allocator = allocator,
                .dirty = project_context.static_dirty,
            }
        );


        if (!t.pause and !gameMode){
            project_context.physics.forEachBitSet(
                struct {
                    alive: *const two_bit,
                    entity_transforms: []Transform2D,
                    comps: []helper.SpriteSet,
                    storage: []helper.SpriteDraw,
                    has_sprite: *const two_bit,
                    physics: *Physics,

                    pub fn call(f: @This(), entity: u32) void {
                        if (!f.alive.testBit(entity)) return;

                        f.physics.Step(entity, &f.entity_transforms[entity]);

                        if (!f.has_sprite.testBit(entity)) return;

                        const set = f.comps[entity];
                        const sprites = f.storage[set.start .. set.start + set.count];

                        for (sprites) |*sprite| {
                            sprite.sprite_pos = .{
                                f.entity_transforms[entity].position.x,
                                f.entity_transforms[entity].position.y,
                            };
                        }
                    }
                }{
                .entity_transforms = project_context.entity_transforms,
                .alive = &project_context.alive,
                .comps = project_context.sprite_components,
                .storage = project_context.sprite_storage.items,
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
                    comps: []helper.SpriteSet,
                    storage: []helper.SpriteDraw,
                    has_sprite: *const two_bit,
                    physics: *Physics,

                    pub fn call(f: @This(), entity: u32) void {
                        if (!f.alive.testBit(entity)) return;

                        f.physics.Step(entity, &f.entity_transforms[entity]);

                        if (!f.has_sprite.testBit(entity)) return;

                        const set = f.comps[entity];
                        const sprites = f.storage[set.start .. set.start + set.count];

                        for (sprites) |*sprite| {
                            sprite.sprite_pos = .{
                                f.entity_transforms[entity].position.x,
                                f.entity_transforms[entity].position.y,
                            };
                        }
                    }
                }{
                    .entity_transforms = project_context.entity_transforms,
                    .alive = &project_context.alive,
                    .comps = project_context.sprite_components,
                    .storage = project_context.sprite_storage.items,
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
            project_context.static_sprite_draws.items,
            cam.view_proj,
            &project_context.static_dirty,
        );

        t.FrameCounter(io);
        g_t.FrameCounter(io);

// ****************************************** Terminal UI *******************************************
        tui.BeginUI();
        if (gameMode){
            try tui.UpdateEngineUI(g_t.fps, t.time_sec, g_t.time_sec, gameMode);
        }else {
            try tui.UpdateEngineUI(t.fps, t.time_sec, g_t.time_sec, gameMode);
        }
        try tui.UpdateCameraUI(cam.pos.x, cam.pos.y, cam.zoom);
        try tui.UpdateMouseUI(mouse.world_pos.x, mouse.world_pos.y);
        for (select_buffer.items) |selected| {
           // _ = selected;
            try tui.Selected(
                selected, 
                &physics, 
                &project_context.physics,
                &project_context.has_sprite, 
                project_context.entity_transforms[selected]
            );
        }
        try tui.FlushUI(io);


    }

}




