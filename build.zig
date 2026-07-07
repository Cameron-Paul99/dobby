const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const vk_lib_name = if (target.result.os.tag == .windows) "vulkan-1" else "vulkan";

    const engine_mod = b.createModule(.{
        .root_source_file = b.path("src/engine/engine.zig"),
        .target = target,
        .optimize = optimize,
    });

    const utils_mod = b.createModule(.{
        .root_source_file = b.path("src/utils/utils.zig"),
        .target = target,
        .optimize = optimize,
    });

    const game_api_mod = b.createModule(.{
        .root_source_file = b.path("src/game_api/game_api.zig"),
        .target = target,
        .optimize = optimize,
    });

    utils_mod.addImport("game_api", game_api_mod);

    engine_mod.addImport("utils", utils_mod);
    engine_mod.addImport("game_api", game_api_mod);
    engine_mod.addIncludePath(b.path("thirdparty/vma"));
    engine_mod.addIncludePath(b.path("thirdparty/sdl3/include"));
    engine_mod.addIncludePath(b.path("thirdparty/miniaudio/"));

    const setup_exe = b.addExecutable(.{
        .name = "Setup",
        .root_module = b.addModule(
            "Setup",
            .{
                .root_source_file = b.path("setup.zig"),
                .target = target,
                .optimize = optimize,
        }),
    });

    setup_exe.root_module.addImport("utils", utils_mod);

    const tui_exe = b.addExecutable(.{
        .name = "TUI",
        .root_module = b.addModule(
            "TUI",
            .{
                .root_source_file = b.path("src/apps/tui.zig"),
                .target = target,
                .optimize = optimize,
            }),
    });

    tui_exe.root_module.addImport("utils", utils_mod);

       // Asset Cooker EXE
    const asset_cooker = b.addExecutable(.{
        .name = "Asset_Cooker",
        .root_module = b.addModule(
            "Asset Cooker",
            .{
                .root_source_file = b.path("src/apps/cooker_main.zig"),
                .target = target,
                .optimize = optimize,
        }),
    });

    asset_cooker.root_module.addImport("utils", utils_mod);
    asset_cooker.root_module.addAnonymousImport("zigimg", .{ .root_source_file = b.path("thirdparty/zigimg/zigimg.zig") });
    // Editor SDL 
    const editor_sdl = b.addExecutable(.{
        .name = "Editor_SDL",
        .root_module = b.addModule(
            "Editor SDL", 
            .{
                .root_source_file = b.path("src/apps/editor_sdl_main.zig"),
                .target = target,
                .optimize = optimize,
        }),
    });
    const game_exe = b.addExecutable(.{
        .name = "Game",
        .root_module = b.addModule(
            "Game",
            .{
                .root_source_file = b.path("src/apps/game_main.zig"),
                .target = target,
                .optimize = optimize,
            }),
    });


    editor_sdl.root_module.addImport("game_api", game_api_mod);
    editor_sdl.root_module.addImport("engine", engine_mod);
    editor_sdl.root_module.addImport("utils", utils_mod);
    editor_sdl.root_module.addAnonymousImport("zigimg", .{ .root_source_file = b.path("thirdparty/zigimg/zigimg.zig") }); 
    editor_sdl.root_module.linkSystemLibrary("SDL3", .{});
    editor_sdl.root_module.linkSystemLibrary("ktx", .{});
    editor_sdl.root_module.linkSystemLibrary("z", .{});

    editor_sdl.root_module.linkSystemLibrary(vk_lib_name, .{});
    editor_sdl.root_module.addIncludePath(.{
        .cwd_relative = "thirdparty/sdl3/include",
    });

    editor_sdl.root_module.addCSourceFile(.{
        .file = b.path("src/engine/vk_mem_alloc.cpp"),
        .flags = &.{},
    });

    editor_sdl.root_module.addIncludePath(b.path("thirdparty/vma/"));
    editor_sdl.root_module.addIncludePath(b.path("thirdparty/miniaudio/"));

    editor_sdl.root_module.addCSourceFile(.{
        .file = b.path("thirdparty/miniaudio/miniaudio.c"),
        .flags = &.{
            "-std=c99",
        },
    });
    editor_sdl.root_module.linkSystemLibrary("pthread", .{});
    editor_sdl.root_module.linkSystemLibrary("m", .{});
    editor_sdl.root_module.linkSystemLibrary("dl", .{});
    editor_sdl.root_module.linkSystemLibrary("asound", .{});
    editor_sdl.root_module.linkSystemLibrary("pulse", .{});

    editor_sdl.root_module.link_libcpp = true;
    
    compile_all_shaders_mod(b, engine_mod);

    editor_sdl.root_module.addIncludePath(.{ .cwd_relative = "/usr/include/vulkan/vulkan.h" });

    game_exe.root_module.strip = true;
    game_exe.root_module.addImport("game_api", game_api_mod);
    game_exe.root_module.addImport("engine", engine_mod);
    game_exe.root_module.addImport("utils", utils_mod);
    game_exe.root_module.addAnonymousImport("zigimg", .{ .root_source_file = b.path("thirdparty/zigimg/zigimg.zig") }); 
    game_exe.root_module.linkSystemLibrary("SDL3", .{});
    game_exe.root_module.linkSystemLibrary("ktx", .{});
    game_exe.root_module.linkSystemLibrary("z", .{});
    game_exe.root_module.linkSystemLibrary(vk_lib_name, .{});
    game_exe.root_module.addIncludePath(.{
        .cwd_relative = "thirdparty/sdl3/include",
    });
    game_exe.root_module.addCSourceFile(.{
        .file = b.path("src/engine/vk_mem_alloc.cpp"),
        .flags = &.{},
    });
    game_exe.root_module.addIncludePath(b.path("thirdparty/vma/"));
    game_exe.root_module.addIncludePath(b.path("thirdparty/miniaudio/"));
    game_exe.root_module.addCSourceFile(.{
        .file = b.path("thirdparty/miniaudio/miniaudio.c"),
        .flags = &.{
            "-std=c99",
        },
    });
    game_exe.root_module.linkSystemLibrary("pthread", .{});
    game_exe.root_module.linkSystemLibrary("m", .{});
    game_exe.root_module.linkSystemLibrary("dl", .{});
    game_exe.root_module.linkSystemLibrary("asound", .{});
    game_exe.root_module.linkSystemLibrary("pulse", .{});
    game_exe.root_module.link_libcpp = true;



  //  _ = asset_cooker;

    // ---- Install both ----
    b.installArtifact(editor_sdl);
    b.installArtifact(asset_cooker);
    b.installArtifact(game_exe);
    b.installFile("Slot.ktx2", "Slot.ktx2");

    // ---- Run steps (stand-alone) ----
    const run_editor_cmd = b.addRunArtifact(editor_sdl);
    run_editor_cmd.step.dependOn(b.getInstallStep());
    const run_editor_step = b.step("run_editor", "Run the SDL editor");
    run_editor_step.dependOn(&run_editor_cmd.step);

    const run_cooker_cmd = b.addRunArtifact(asset_cooker);
    run_cooker_cmd.step.dependOn(b.getInstallStep());
    const run_cooker_step = b.step("run_cooker", "Run the asset cooker");
    run_cooker_step.dependOn(&run_cooker_cmd.step);

    const setup_cmd = b.addRunArtifact(setup_exe);
    setup_cmd.step.dependOn(b.getInstallStep());
    const setup_step = b.step("setup", "Setup engine");
    setup_step.dependOn(&setup_cmd.step);

    const tui_cmd = b.addRunArtifact(tui_exe);
    tui_cmd.step.dependOn(b.getInstallStep());
    const tui_step = b.step("tui", "terminal interface for dev");
    tui_step.dependOn(&tui_cmd.step);

    // Run All
    const run_all_bg = b.addSystemCommand(&.{
        "bash", "-c",
        "trap 'kill 0' EXIT; zig build run_editor & PID2=$!; zig build tui & PID3=$!; wait $PID2 $PID3",
    }); 

    const run_dev = b.step("run_dev", "Run cooker + editor concurrently");
    run_dev.dependOn(&run_all_bg.step); 

    const project_name = b.option([]const u8, "project", "Project name") orelse "loa";

    const options = b.addOptions();
    options.addOption([]const u8, "project_name", project_name);
    game_exe.root_module.addOptions("build_options", options);


   // const install_dir = std.Build.InstallDir{ .custom = project_name };
    const version = b.option([]const u8, "version", "Build version") orelse "1";
    const release_dir = b.fmt("{s}_v{s}", .{project_name, version});

    const install_exe = b.addInstallArtifact(game_exe, .{
        .dest_dir = .{ 
            .override = .{
                .custom = release_dir,
            },
        },
    });


    const install_assets = b.addInstallDirectory(.{
        .source_dir = b.path(b.fmt("projects/{s}/cooked/atlases", .{project_name})),
        .install_dir = .{ .custom = release_dir },
        .install_subdir = b.fmt("projects/{s}/cooked/atlases", .{project_name}),
    });

 //   const install_lib_dir = b.addInstallDirectory(.{
 //       .source_dir = b.path(b.fmt("projects/{s}/src/scripts/zig-out/lib", .{project_name})),
 //       .install_dir = .{ .custom = release_dir },
 //      .install_subdir = b.fmt("projects/{s}/src/scripts/zig-out/lib", .{project_name}),
 //   });

  // const stripped_so = b.fmt("{s}/lib/lib{s}_game.so", .{release_dir, project_name});
  // const lib_path = b.path(b.fmt("projects/{s}/src/scripts/zig-out/lib/lib{s}_game.so", .{project_name, project_name})); 
 //  const strip_lib = b.addSystemCommand(&.{
  //      "strip",
 //       "--strip-all",
 //       "-o",
 //       b.fmt("zig-out/{s}/{s}", .{release_dir , lib_path}),
 //       b.fmt("projects/{s}/src/scripts/zig-out/lib/lib{s}_game.so", .{project_name, project_name}),
 //   });

 //  const install_lib = b.addInstallFile(
 //       .{ .cwd_relative = b.fmt("zig-out/{s}/{s}", .{release_dir}, lib_path) },
 //       stripped_so,
//    ); 

//    install_lib.step.dependOn(&strip_lib.step);
//

    const so_name = b.fmt("lib{s}_game.so", .{project_name});
    const so_src = b.fmt("projects/{s}/src/scripts/zig-out/lib/lib{s}_game.so", .{project_name, project_name});
    const so_dst = b.fmt("zig-out/{s}/projects/{s}/src/scripts/zig-out/lib/lib{s}_game.so", .{release_dir, project_name, project_name});

    const mkdir = b.addSystemCommand(&.{
        "mkdir", "-p",
        b.fmt("zig-out/{s}/projects/{s}/src/scripts/zig-out/lib", .{release_dir, project_name}),
    });

    const strip_lib = b.addSystemCommand(&.{
        "strip",
        "--strip-all",
        "-o",
        so_dst,
        so_src,
    });
    strip_lib.step.dependOn(&mkdir.step);

    const install_lib = b.addInstallFile(
        .{ .cwd_relative = so_dst },
        b.fmt("{s}/projects/{s}/src/scripts/zig-out/lib/{s}", .{release_dir, project_name, so_name}),
    );
install_lib.step.dependOn(&strip_lib.step);

    const install_slot_ktx = b.addInstallFile(
        b.path("Slot.ktx2"),
        b.fmt("{s}/Slot.ktx2", .{release_dir}),
    );

    const game_cmd = b.addRunArtifact(game_exe);
    game_cmd.step.dependOn(b.getInstallStep());

    game_cmd.step.dependOn(&install_exe.step);
    game_cmd.step.dependOn(&install_assets.step);
    game_cmd.step.dependOn(&install_lib.step);
    //game_cmd.step.dependOn(&install_lib_dir.step);
    game_cmd.step.dependOn(&install_slot_ktx.step);


    const game_step = b.step("game", "build and run game");
    game_step.dependOn(&game_cmd.step);

}

fn compile_all_shaders_mod(b: *std.Build, mod: *std.Build.Module) void {
    const shaders_dir = b.build_root.handle.openDir(b.graph.io, "base_shaders", .{ .iterate = true })
        catch @panic("Failed to open shaders directory");

    var it = shaders_dir.iterate();
    while (it.next(b.graph.io) catch @panic("Failed to iterate")) |entry| {
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".glsl")) continue;

        const name = entry.name[0 .. entry.name.len - ".glsl".len];
        add_shader_mod(b, mod, name);
    }
}

fn add_shader_mod(b: *std.Build, mod: *std.Build.Module, name: []const u8) void {
    const source = b.fmt("base_shaders/{s}.glsl", .{name});

    const cmd = b.addSystemCommand(&.{ "glslangValidator", "-V" });
    cmd.addArg("-o");

    // This output file lives in the build cache/output space (not your repo)
    const out = cmd.addOutputFileArg(b.fmt("shaders/{s}.spv", .{name}));
    cmd.addFileArg(b.path(source));

    // Make it available at compile-time as an import
    mod.addAnonymousImport(b.fmt("shaders/{s}.spv", .{name}), .{
        .root_source_file = out,
    });
}

