const std = @import("std");
const engine = @import("engine");

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

    // Project
    var proj = try utils.LoadProject(io , allocator);
    defer proj.deinit(allocator);

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

    // Scripts path
    const scripts_path = try std.fmt.allocPrint(
        allocator,
        src_scripts_path,
        .{ proj.parsed.value.name },
    );
    defer allocator.free(scripts_path);

    // Physics
    var physics = try Physics.init(MAX_ENTITIES, allocator);
    defer physics.deinit(allocator);

    Bridge.physics_ctx = &physics;

    // Project context
    var project_context = try ProjectContext.init(
        allocator, 
        proj.parsed.value.name,
        io,
    );
    defer project_context.deinit();

    // Project context settings
    Bridge.g_active_ctx = &project_context;
    project_context.game_api.user_data = Bridge.g_active_ctx;
    Bridge.cam_ctx = &cam;
    Bridge.mouse_ctx = &mouse;

    project_context.proj = proj.parsed.value;
    project_context.io = io;

    project_context.alive.clearAll();
    project_context.physics.clearAll();
    project_context.has_sprite.clearAll();

    // Restart time
    g_t.HardRestart(io);

    while (!game_window.should_close){



    }

}
