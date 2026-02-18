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
const time = utils.time;
const Camera = utils.camera;
const Mouse = utils.mouse;
const AtlasManager = utils.atlas_manager;
const SceneManager = utils.scene_manager;


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
    const id = ctx.alive.Create() orelse unreachable;
    std.log.info("Entity {d} is alive", .{id});
    return id;
}

pub export fn SpawnSprite(desc: *const g_api.SpriteDesc, id: u32) callconv(.c) void {
    
    const ctx = g_active_ctx;

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
}
pub export fn GetAllocator() callconv(.c) *anyopaque {
    return &g_active_ctx.allocator;
}

pub export fn SetSpritePos(entity: u32, x: f32, y: f32) callconv(.c) void {
    _ = entity;
    _ = x;
    _ = y;
}

// ****************************************** PROCJECT CONTEXT *******************************************
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
    paused: bool = true,
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
                .desired = &[_]atlas_mod.AtlasEntry{},
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
                .scenes = try std.ArrayList(SceneManager.Scene).initCapacity(allocator, 0),
                .atlas_alias_table = try std.ArrayList(atlas_mod.AtlasAliasId_u32)
                    .initCapacity(allocator, 0),
                .scene_connection_table = try std.ArrayList(SceneManager.SceneId_u32)
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
        self.alive.deinit();
        self.has_sprite.deinit();
        self.lib.?.close();
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


// ****************************************** Rendering START *******************************************

    while (!game_window.should_close){
        
        game_window.pollEvents(&renderer);

        input.BuildEditorIntent( 
            &editor_input,
            game_window.raw_input,
            &t,
        );

        t.Runnin();
    
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
            if (!t.pause) game_update(t.time_sec);
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

            const prev_size = project_context.atlas_manager.atlas_list.items.len;
            project_context.atlas_manager.desired = project_context.atlas_manager.manifest.?.parsed.value.atlases; 
            
            const new_size = try project_context.atlas_manager.ApplyMetadata(
                allocator,
            );

            for (prev_size..new_size) |i| {
                const new_atlas = project_context.atlas_manager.atlas_list.items[i];
                try renderer.AddAtlasGPU(&core, new_atlas, allocator);
            }

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




