const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "dobby",
        .root_module = b.addModule(
            "dobby", 
            .{
                .root_source_file = b.path("src/main.zig"),
                .target = target,
                .optimize = optimize,
        }),
    });


    const vk_lib_name = if (target.result.os.tag == .windows) "vulkan-1" else "vulkan";
    
    exe.linkSystemLibrary("SDL3");
    exe.linkSystemLibrary("ktx");
    exe.linkSystemLibrary("z");

    exe.linkSystemLibrary(vk_lib_name);
    exe.addIncludePath(.{ .cwd_relative = "thirdparty/sdl3/include" });
    exe.addCSourceFile(.{ .file = b.path("src/vk_mem_alloc.cpp"), .flags = &.{ "" } });
    exe.addIncludePath(b.path("thirdparty/vma/"));

    //exe.linkLibC();
    exe.linkLibCpp();
    
    compile_all_png_active(b, exe);
    compile_all_shaders(b, exe);

    exe.addIncludePath(.{ .cwd_relative = "/usr/include/vulkan/vulkan.h" });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}

fn compile_all_png_active(b: *std.Build, exe: *std.Build.Step.Compile) void {

    var png_dir = if (@hasDecl(@TypeOf(b.build_root.handle), "openIterableDir"))
        b.build_root.handle.openIterableDir("textures_src", .{}) catch @panic("Failed to open textures_src directory")
    else
        b.build_root.handle.openDir("textures_src", .{ .iterate = true }) catch @panic("Failed to open textures_src directory");

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

    const source = std.fmt.allocPrint(b.allocator, "textures_src/{s}.png", .{name}) catch @panic("OOM");
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
        b.build_root.handle.openIterableDir("shaders", .{}) catch @panic("Failed to open shaders directory")
    else
        b.build_root.handle.openDir("shaders", .{ .iterate = true }) catch @panic("Failed to open shaders directory");

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
    const source = std.fmt.allocPrint(b.allocator, "shaders/{s}.glsl", .{name}) catch @panic("OOM");
    const outpath = std.fmt.allocPrint(b.allocator, "shaders/{s}.spv", .{name}) catch @panic("OOM");

    const shader_compilation = b.addSystemCommand(&.{ "glslangValidator" });
    shader_compilation.addArg("-V");
    shader_compilation.addArg("-o");
    const output = shader_compilation.addOutputFileArg(outpath);
    shader_compilation.addFileArg(b.path(source));

    exe.root_module.addAnonymousImport(name, .{ .root_source_file = output });
}
