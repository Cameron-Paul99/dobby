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

    engine_mod.addImport("utils", utils_mod);
    engine_mod.addIncludePath(b.path("thirdparty/vma"));
    engine_mod.addIncludePath(b.path("thirdparty/sdl3/include"));

    // Asset Cooker EXE
    const asset_cooker = b.addExecutable(.{
        .name = "Asset Cooker",
        .root_module = b.addModule(
            "Asset Cooker",
            .{
                .root_source_file = b.path("src/apps/cooker_main.zig"),
                .target = target,
                .optimize = optimize,
        }),
    });

    asset_cooker.root_module.addImport("utils", utils_mod);

    // Editor SDL 
    const editor_sdl = b.addExecutable(.{
        .name = "Editor SDL",
        .root_module = b.addModule(
            "Editor SDL", 
            .{
                .root_source_file = b.path("src/apps/editor_sdl_main.zig"),
                .target = target,
                .optimize = optimize,
        }),
    });

    editor_sdl.root_module.addImport("engine", engine_mod);
    editor_sdl.root_module.addImport("utils", utils_mod);
    editor_sdl.root_module.addAnonymousImport("zigimg", .{ .root_source_file = b.path("thirdparty/zigimg/zigimg.zig") }); 
    editor_sdl.linkSystemLibrary("SDL3");
    editor_sdl.linkSystemLibrary("ktx");
    editor_sdl.linkSystemLibrary("z");

    editor_sdl.linkSystemLibrary(vk_lib_name);
    editor_sdl.addIncludePath(.{ .cwd_relative = "thirdparty/sdl3/include" });
    editor_sdl.addCSourceFile(.{ .file = b.path("src/engine/vk_mem_alloc.cpp"), .flags = &.{ "" } });
    editor_sdl.addIncludePath(b.path("thirdparty/vma/"));
   // exe.linkLibC();
    editor_sdl.linkLibCpp();
   

    
    compile_all_png_active(b, editor_sdl);
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

}

fn compile_all_png_active(b: *std.Build, exe: *std.Build.Step.Compile) void {

    var png_dir = if (@hasDecl(@TypeOf(b.build_root.handle), "openIterableDir"))
        b.build_root.handle.openIterableDir("assets/src/textures", .{}) catch @panic("Failed to open textures_src directory")
    else
        b.build_root.handle.openDir("assets/src/textures", .{ .iterate = true }) catch @panic("Failed to open textures_src directory");

    defer png_dir.close();

    const assets_step = b.step("textures", "Convert textures to runtime format");

    var file_it = png_dir.iterate();
    while (file_it.next() catch @panic("Failed to iterate png directory")) |entry| {
        if (entry.kind == .file) {
            const ext = std.fs.path.extension(entry.name);
            if (std.mem.eql(u8, ext, ".png")) {
                const basename = std.fs.path.basename(entry.name);
                const name = basename[0..basename.len - ext.len];

                std.debug.print("Found png file to compile: {s}. Compiling with name: {s}\n", .{ entry.name, name });

                convert_to_ktx2(b, assets_step, name);
                //add_shader(b, exe, name);
            }
        }
    }

    exe.step.dependOn(assets_step);
}
fn convert_to_ktx2(
    b: *std.Build, 
    assets_step: *std.Build.Step, 
    name: []const u8) void{

    const toktx = b.findProgram(&.{ "toktx" }, &.{}) catch
        @panic("toktx not found. Install KTX-Software tools.");

    const source = std.fmt.allocPrint(b.allocator, "assets/src/textures/{s}.png", .{name}) catch @panic("OOM");
    const outpath = std.fmt.allocPrint(b.allocator, "textures/{s}.ktx2", .{name}) catch @panic("OOM");

    const out_ktx2_abs = b.pathJoin(&.{ b.install_prefix, outpath });
    const tex_step = b.addSystemCommand(&.{
        toktx,
        "--assign_oetf", "srgb",
        "--bcmp",       // BasisU supercompression
        "--genmipmap",  // generate mipmaps offline
        out_ktx2_abs,
        source,
    });

    assets_step.dependOn(&tex_step.step);
   
}

fn compile_all_shaders(b: *std.Build, exe: *std.Build.Step.Compile) void {
    // This is a fix for a change between zig 0.11 and 0.12

    const shaders_dir = if (@hasDecl(@TypeOf(b.build_root.handle), "openIterableDir"))
        b.build_root.handle.openIterableDir("assets/src/shaders", .{}) catch @panic("Failed to open shaders directory")
    else
        b.build_root.handle.openDir("assets/src/shaders", .{ .iterate = true }) catch @panic("Failed to open shaders directory");

    var file_it = shaders_dir.iterate();
    while (file_it.next() catch @panic("Failed to iterate shader directory")) |entry| {
        if (entry.kind == .file) {
            const ext = std.fs.path.extension(entry.name);
            if (std.mem.eql(u8, ext, ".glsl")) {
                const basename = std.fs.path.basename(entry.name);
                const name = basename[0..basename.len - ext.len];

                std.debug.print("Found shader file to compile: {s}. Compiling with name: {s}\n", .{ entry.name, name });
                add_shader(b, exe, name);
            }
        }
    }
}

fn add_shader(b: *std.Build, exe: *std.Build.Step.Compile, name: []const u8) void {
    const source = std.fmt.allocPrint(b.allocator, "assets/src/shaders/{s}.glsl", .{name}) catch @panic("OOM");
    const outpath = std.fmt.allocPrint(b.allocator, "shaders/{s}.spv", .{name}) catch @panic("OOM");

    const shader_compilation = b.addSystemCommand(&.{ "glslangValidator" });
    shader_compilation.addArg("-V");
    shader_compilation.addArg("-o");
    //shader_compilation.addArg(outpath);
    const output = shader_compilation.addOutputFileArg(outpath);
    shader_compilation.addFileArg(b.path(source));
    
    exe.root_module.addAnonymousImport( outpath , .{ .root_source_file = output });

    exe.step.dependOn(&shader_compilation.step);
}

fn compile_all_shaders_mod(b: *std.Build, mod: *std.Build.Module) void {
    const shaders_dir = b.build_root.handle.openDir("assets/src/shaders", .{ .iterate = true })
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
    const source = b.fmt("assets/src/shaders/{s}.glsl", .{name});

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
