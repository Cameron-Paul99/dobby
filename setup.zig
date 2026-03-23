const std = @import("std");
const utils = @import("utils");

const cooked_shaders_path = "projects/{s}/cooked/shaders";
const cooked_atlases_path = "projects/{s}/cooked/atlases";
const cooked_manifest_atlases_path = "projects/{s}/cooked/atlases/manifest.json";
const src_textures_path = "projects/{s}/src/textures";
const src_shaders_path = "projects/{s}/src/shaders";
const src_scripts_path = "projects/{s}/src/scripts";
const src_scripts_path_build = "projects/{s}/src/scripts/";
const src_scripts_build_zig = "projects/{s}/src/scripts/build.zig";
const src_scripts_game_zig = "projects/{s}/src/scripts/game.zig";

const build_zig_contents =
    \\const std = @import("std");
    \\
    \\pub fn build(b: *std.Build) void {{
    \\    //const project_bin_dir =
    \\    //    b.path("zig-out/bin");
    \\
    \\    const target = b.standardTargetOptions(.{{}});
    \\    const optimize = b.standardOptimizeOption(.{{}});
    \\
    \\    const game = b.addLibrary(.{{
    \\        .name = "{s}_game",
    \\        .linkage = .dynamic,
    \\        .root_module = b.addModule(
    \\            "{s}_game",
    \\            .{{
    \\                .root_source_file = b.path("game.zig"),
    \\                .target = target,
    \\                .optimize = optimize,
    \\            }},
    \\        ),
    \\    }});
    \\
    \\    const game_api_mod = b.createModule(.{{
    \\        .root_source_file = b.path("../../../../src/game_api/game_api.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    }});
    \\
    \\    const utils_mod = b.createModule(.{{
    \\        .root_source_file = b.path("../../../../src/utils/utils.zig"),
    \\        .target = target,
    \\        .optimize = optimize,
    \\    }});
    \\
    \\    game.root_module.addImport("game_api", game_api_mod);
    \\    game.root_module.addImport("utils", utils_mod);
    \\
    \\    b.installArtifact(game);
    \\}}
    \\
;

const manifest_contents = 
    \\{
    \\  "version": 1,
    \\  "atlases": []
    \\}
;
const active_project_contents =
    \\{
    \\"name": "",
    \\"path": ""
    \\}
;
const game_zig_contents = 
    \\const GameAPI = @import("game_api").GameAPI;
    \\const GameMemory = @import("game_api").GameMemory;
    \\const Physics = @import("game_api").PhysicsAPI;
    \\const Input = @import("game_api").InputKeyExtern;
    \\const Mouse = @import("game_api").MouseAPI;
    \\const Camera = @import("game_api").Camera2DAPI;
    \\const Sprite = @import("game_api").SpriteAPI;
    \\const std = @import("std");
    \\
    \\pub var g_api: *GameAPI = undefined;
    \\pub var g_memory: *GameMemory = undefined;
    \\pub var g_physics: *Physics = undefined;
    \\pub var g_camera: *Camera = undefined; 
    \\pub var g_mouse: *Mouse = undefined;
    \\pub var g_sprite: *Sprite = undefined;
    \\var g_initialized: bool = false;
    \\var g_allocator: ?*std.mem.Allocator = null;
    \\
    \\pub export fn game_init(
    \\api: *GameAPI, 
    \\game_memory: *GameMemory, 
    \\physics: *Physics, 
    \\camera: *Camera, 
    \\mouse: *Mouse,
    \\spriteAPI: *Sprite) callconv(.c) void {

    \\  g_api = api;
    \\  g_memory = game_memory;
    \\  g_physics = physics;
    \\  g_camera = camera;
    \\  g_mouse = mouse;
    \\  g_sprite = spriteAPI;

    \\  const allocator_fn = g_api.*.get_allocator();
    \\  const allocator: *std.mem.Allocator = @ptrCast(@alignCast(allocator_fn));
    \\  g_allocator = allocator;
    \\}
    \\pub export fn game_start() callconv(.c) void {
    \\
    \\}
    \\ pub export fn game_update(time_sec: f64) callconv(.c) void{
    \\ _ = time_sec;
    \\}
    \\pub export fn game_input_pressed(key: u8) callconv(.c) void {
    \\    _ = key;
    \\}
    \\pub export fn game_deinit() callconv(.c) void {
    \\
    \\}
    \\pub export fn game_input_down(key: u8) callconv(.c) void {
    \\  _ = key;
    \\}
    \\pub export fn game_input_up(key: u8) callconv(.c) void {
    \\    _ = key;
    \\}
    \\pub export fn reload_game() callconv(.c) void {
    \\
    \\}
;
 pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var stdin_buffer: [512]u8 = undefined;
    var stdin_reader = std.fs.File.stdin().reader(&stdin_buffer);
    const stdin = &stdin_reader.interface;

    var stdout_buffer : [512]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    var setup_finished = false;

    var file: std.fs.File = undefined;

     file = std.fs.cwd().openFile(".active_project.json", .{}) catch |err| switch (err){
        error.FileNotFound => blk: {

            const new_file = try std.fs.cwd().createFile(
                ".active_project.json",
                .{ .truncate = true },
            );

            break :blk new_file;
        },
        else => return err,

    };


    defer file.close();

    var proj_list = try std.ArrayList([]const u8).initCapacity(allocator, 0);
    defer proj_list.deinit(allocator);

    try stdout.print("\n", .{});
    const welcoming = 
        \\Hello
        \\Welcome to Dobby Engine
        \\Designed by Cameron Paul
    ;

    try stdout.print("{s}\n", .{welcoming});

    try stdout.print("\n", .{});
    var project_selected = false;

    var dir = try std.fs.cwd().openDir("projects", .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    var proj_count: u32 = 0;

    try stdout.print("Here are your projects\n", .{});

    try stdout.print("\n", .{});

    while(try it.next()) |entry| {

        if (entry.kind != .directory) continue;

        try stdout.print("{d}:{s} ", .{proj_count, entry.name});
        try proj_list.append(allocator, entry.name);
        proj_count += 1;

    }
    try stdout.print("\n", .{});
    try stdout.print("\n", .{});
    try stdout.print("Type in number associated with the project or create a new project by typing in 'new'. Type enter with your choice\n", .{});

    var project_id: u32 = 0;
    var existing_proj_name: ?[]const u8 = null;
   // _ = project_id;
    var new_proj = false;

    try stdout.flush();
    while(!project_selected){

        const line = try stdin.takeDelimiterExclusive('\n'); 
        _ = try stdin.discardDelimiterInclusive('\n');

        if (std.mem.eql(u8, line, "new")) {
            try stdout.print("Creating new project...\n", .{});
            project_selected = true;
            new_proj = true;
            try stdout.flush();
            break;
        }
        project_id = std.fmt.parseInt(u32, line, 10) catch {
            try stdout.print("Invalid input: '{s}'\n", .{line});
            try stdout.flush();
            continue;
        };
        if (project_id >= 0 and project_id <= proj_count){
            try stdout.print("Selected project #{d}\n", .{project_id});
            existing_proj_name = proj_list.items[project_id];
            try stdout.flush();
            break;
        }
    }

    try stdout.flush();

    try std.fs.cwd().writeFile(.{
        .sub_path = ".active_project.json",
        .data = active_project_contents,
    });

    if (new_proj){

        try stdout.print("Name the new project\n", .{});
        try stdout.flush();
        
        while(true){
            const line = try stdin.takeDelimiterExclusive('\n'); 
            _ = try stdin.discardDelimiterInclusive('\n');
            if (std.mem.eql(u8, line, "")) {
                try stdout.print("Invalid input\n", .{});
                try stdout.flush();
                continue;
            }
            const path = try std.fmt.allocPrint(
                allocator,
                "projects/{s}",
                .{line},
            );
            defer allocator.free(path);

            const asset_cooked_path = try std.fmt.allocPrint(
                allocator,
                cooked_atlases_path,
                .{line},
            );
            defer allocator.free(asset_cooked_path);

            const asset_manifest_cooked_path = try std.fmt.allocPrint(
                allocator,
                cooked_manifest_atlases_path,
                .{line},
            );
            defer allocator.free(asset_manifest_cooked_path);

            const asset_cooked_shaders_path = try std.fmt.allocPrint(
                allocator,
                cooked_shaders_path,
                .{line},
            );
            defer allocator.free(asset_cooked_shaders_path);

            const asset_src_texture_path = try std.fmt.allocPrint(
                allocator,
                src_textures_path,
                .{line},
            );
            defer allocator.free(asset_src_texture_path);

            const asset_src_shaders_path = try std.fmt.allocPrint(
                allocator,
                src_shaders_path,
                .{line},
            );
            defer allocator.free(asset_src_shaders_path);

            const asset_src_scripts_path = try std.fmt.allocPrint(
                allocator,
                src_scripts_path,
                .{line},
            );
            defer allocator.free(asset_src_scripts_path);

            const build_zig_path = try std.fmt.allocPrint(
                allocator,
                src_scripts_build_zig,
                .{line},
            );
            defer allocator.free(build_zig_path);

            const game_zig_path = try std.fmt.allocPrint(
                allocator,
                src_scripts_game_zig,
                .{line},
            );
            defer allocator.free(game_zig_path);

            const build_zig_proj_contents = try std.fmt.allocPrint(
                allocator,
                build_zig_contents,
                .{ line, line },
            );
            defer allocator.free(build_zig_proj_contents);

            try std.fs.cwd().makePath(path);
            try std.fs.cwd().makePath(asset_cooked_path);
            try std.fs.cwd().makePath(asset_cooked_shaders_path);
            try std.fs.cwd().makePath(asset_src_texture_path);
            try std.fs.cwd().makePath(asset_src_shaders_path);
            try std.fs.cwd().makePath(asset_src_scripts_path);
            try std.fs.cwd().writeFile(.{
                    .sub_path = build_zig_path,
                    .data = build_zig_proj_contents,
            });
            try std.fs.cwd().writeFile(.{
                    .sub_path = game_zig_path,
                    .data = game_zig_contents,
            });

            try std.fs.cwd().writeFile(.{
                    .sub_path = asset_manifest_cooked_path,
                    .data = manifest_contents,
            });

            const name = try std.fmt.allocPrint(
                allocator,
                "{s}",
                .{line},
            );
            defer allocator.free(name);

            const proj = utils.Project {
                .name = try allocator.dupe(u8, name),
                .path = try allocator.dupe(u8, path),
            };
            defer allocator.free(proj.name);
            defer allocator.free(proj.path);

            try utils.WriteActiveProject(proj, allocator);

            var child = std.process.Child.init(
                &[_][]const u8{
                    "zig", "build",
                },
                allocator,
            );
            child.cwd = asset_src_scripts_path;
            child.stdin_behavior = .Inherit;
            child.stdout_behavior = .Inherit;
            child.stderr_behavior = .Inherit;

            const term = try child.spawnAndWait();
    
            switch (term) {
                .Exited => |code| {
                    std.debug.print("Script exited with code {}\n", .{code});
                },
                else => {
                    std.debug.print("Script crashed\n", .{});
                },
            }
                break;
            }

            setup_finished = true;

    }else if (existing_proj_name) |name| {

            const path = try std.fmt.allocPrint(
                allocator,
                "projects/{s}",
                .{name},
            );
            defer allocator.free(path);

            const proj = utils.Project {
                .name = try allocator.dupe(u8, name),
                .path = try allocator.dupe(u8, path),
            };
            defer allocator.free(proj.name);
            defer allocator.free(proj.path);

            try utils.WriteActiveProject(proj, allocator);
            setup_finished = true;

    }

    if (setup_finished) {
        var child = std.process.Child.init(
            &[_][]const u8{
                "zig", "build", "run_dev",
            },
            allocator,
        );

        child.stdin_behavior = .Inherit;
        child.stdout_behavior = .Inherit;
        child.stderr_behavior = .Inherit;

        const term = try child.spawnAndWait();
    
        switch (term) {
            .Exited => |code| {
                std.debug.print("Script exited with code {}\n", .{code});
            },
            else => {
                std.debug.print("Script crashed\n", .{});
            },
        }
    }

}
