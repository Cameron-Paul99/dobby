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

    const lua_dep = b.dependency("zlua", .{
        .target = target,
        .optimize = optimize,
    });

    engine_mod.addImport("utils", utils_mod);
    engine_mod.addIncludePath(b.path("thirdparty/vma"));
    engine_mod.addIncludePath(b.path("thirdparty/sdl3/include"));

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
   // engine_mod.addIncludePath( b.path("thirdparty/lua/src"));
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

    editor_sdl.root_module.addImport("engine", engine_mod);
    editor_sdl.root_module.addImport("zlua", lua_dep.module("zlua"));
    editor_sdl.root_module.addImport("utils", utils_mod);
    editor_sdl.root_module.addAnonymousImport("zigimg", .{ .root_source_file = b.path("thirdparty/zigimg/zigimg.zig") }); 
    editor_sdl.linkSystemLibrary("SDL3");
    editor_sdl.linkSystemLibrary("ktx");
    editor_sdl.linkSystemLibrary("z");
  //  editor_sdl.linkSystemLibrary("lua");

    editor_sdl.linkSystemLibrary(vk_lib_name);
    editor_sdl.addIncludePath(.{ .cwd_relative = "thirdparty/sdl3/include" });
    editor_sdl.addCSourceFile(.{ .file = b.path("src/engine/vk_mem_alloc.cpp"), .flags = &.{ "" } });
    editor_sdl.addIncludePath(b.path("thirdparty/vma/"));
   // exe.linkLibC();
    editor_sdl.linkLibCpp();
    

    compile_all_shaders_mod(b, engine_mod);

    editor_sdl.addIncludePath(.{ .cwd_relative = "/usr/include/vulkan/vulkan.h" });

    // ---- Install both ----
    b.installArtifact(editor_sdl);
    b.installArtifact(asset_cooker);

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
    // Run All
    const run_all_bg = b.addSystemCommand(&.{
        "sh", "-c",
        "zig build run_cooker & zig build run_editor & wait; kill 0",
    });


    const run_dev = b.step("run_dev", "Run cooker + editor concurrently");
    run_dev.dependOn(&run_all_bg.step);

}

fn compile_all_shaders_mod(b: *std.Build, mod: *std.Build.Module) void {
    const shaders_dir = b.build_root.handle.openDir("base_shaders", .{ .iterate = true })
        catch @panic("Failed to open shaders directory");

    var it = shaders_dir.iterate();
    while (it.next() catch @panic("Failed to iterate")) |entry| {
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

