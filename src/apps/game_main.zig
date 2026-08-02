const std = @import("std");
const utils = @import("utils");
const engine = @import("engine");
const zigimg = @import("zigimg");
const g_api = @import("game_api");
const tui = @import("tui.zig");
const Bridge = @import("bridge.zig");
const build_options = @import("build_options");

const ProjectContext = @import("editor_sdl_main.zig").ProjectContext;
const RebuildScripts = @import("editor_sdl_main.zig").RebuildScripts;

pub var is_active = true;

const core_mod = engine.core;
const swapchain_mod = engine.swapchain;
const render = engine.renderer;
const helper = engine.helper;
const text = engine.textures;
const input = engine.input;
const c = engine.c;
const sdl = engine.sdl;

const algo = utils.algo;
const atlas_mod = utils.atlas;
const two_bit = utils.two_bit;
const time = utils.time;
const Camera = utils.camera;
const Mouse = utils.mouse;
const Physics = utils.physics;
const Io = std.Io;

const Transform2D = g_api.Transform2D;
const PhysicsAPI = g_api.PhysicsAPI;

const MAX_ENTITIES: u32 = 100_000;

var g_gpa = std.heap.DebugAllocator(.{}){};
pub var g_allocator: std.mem.Allocator = undefined;

const cooked_atlases_path = "projects/{s}/cooked/atlases/";

pub fn main(init: std.process.Init) !void {

    // IO and Time
    const io = init.io;
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
    _ = c.SDL_GetWindowSizeInPixels(
        game_window.window, 
        &drawable_w, 
        &drawable_h
    );

    game_window.screen_width = drawable_w;
    game_window.screen_height = drawable_h;

    // Camera 
    var cam = Camera.init(
        @floatFromInt(game_window.screen_width),
        @floatFromInt(game_window.screen_height)
    ); 

    // Mouse
    var mouse = Mouse{};
    std.log.info("mouse world: {d},{d}", .{mouse.world_pos.x, mouse.world_pos.y});

    const project_name = build_options.project_name;

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
        .{ project_name},
    );
    defer allocator.free(atlas_path); 

    const proj_atlas_path = try allocator.dupeZ(u8 , atlas_path);
    defer allocator.free(proj_atlas_path);

    // Physics
    var physics = try Physics.init(MAX_ENTITIES, allocator);
    defer physics.deinit(allocator);

    Bridge.physics_ctx = &physics;

    // Project context
    var project_context = try ProjectContext.init(
        allocator, 
        project_name,
        io,
    );
    defer project_context.deinit();

    // Project context settings
    Bridge.g_active_ctx = &project_context;
    project_context.game_api.user_data = Bridge.g_active_ctx;
    Bridge.cam_ctx = &cam;
    Bridge.mouse_ctx = &mouse;
    Bridge.g_t = &g_t;
    Bridge.game_active = true;

    project_context.io = io;

    project_context.alive.clearAll();
    project_context.physics.clearAll();
    project_context.has_sprite.clearAll();

    try project_context.ReloadProjectScripts();

    project_context.atlas_manager.manifest = try atlas_mod.ReadManifestGame(
        io,
        project_name, 
        allocator
    );

    try project_context.atlas_manager.ApplyMetadata(
        &renderer,
        &core,
        project_context.atlas_manager.manifest.?.parsed.value.atlases,
        allocator,
    );
    // Restart time
    g_t.HardRestart(io);

    while (!game_window.should_close){

        game_window.pollEvents(&renderer, &project_context.game_input);
        if (project_context.game_input.game_input_held) |held_fn| {
            var bits = game_window.raw_input.buttons_down;
            while (bits != 0) {
                const bit_index = @ctz(bits);
                held_fn(bit_index);
                bits &= bits - 1; // clear lowest set bit
            }
        }
        g_t.Runnin(io);
        if (!game_window.gameMode) {
            if (project_context.game_start) |game_start| {
                    game_start();
            }
            game_window.gameMode = true;
        }

        cam.UpdateCameraAttributes(
            cam.zoom, 
            cam.delta,
        );

        cam.UpdateViewProj(
            @floatFromInt(game_window.screen_width),
            @floatFromInt(game_window.screen_height),
        );

        mouse.Update(
            game_window.raw_input.mouse_pos,
            &cam,
            @floatFromInt(game_window.screen_width),
            @floatFromInt(game_window.screen_height),
        );

        if (project_context.game_update) |game_update| {
            if (!g_t.pause) {
                game_update(g_t.time_sec);
            }
        }else{
            std.log.info("We aren't updating", .{});
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

        if (!g_t.pause) {
            project_context.physics.forEachBitSet(
                struct {
                    alive: *const two_bit,
                    dt: f64,
                    entity_transforms: []Transform2D,
                    comps: []helper.SpriteSet,
                    storage: []helper.SpriteDraw,
                    has_sprite: *const two_bit,
                    physics: *Physics,

                    pub fn call(f: @This(), entity: u32) void {
                        if (!f.alive.testBit(entity)) return;

                        f.physics.Step(entity, f.dt, &f.entity_transforms[entity]);

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
                    .dt = g_t.delta_sec,
                    .comps = project_context.sprite_components,
                    .storage = project_context.sprite_storage.items,
                    .has_sprite = &project_context.has_sprite,
                    .physics = &physics,
                }
            );
        }

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

        g_t.FrameCounter(io);

    }

}
