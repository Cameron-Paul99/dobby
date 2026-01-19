const std = @import("std");
const zigimg = @import("zigimg");
const utils = @import("utils");
const notify = utils.notify;

//{
//  "version": 1,
//  "atlases": [
//    { "id": 0, "path": "atlases/opaque_0.ktx2", "rev": 12 },
//    { "id": 1, "path": "atlases/ui_0.ktx2",      "rev": 3 }
//  ]
//}




pub const Cooker = struct {
    time_to_cook_textures: bool = false,
    time_to_cook_shaders: bool = false,

    pub fn CookShaders(self: *Cooker) void {
        _ = self;

    }


    pub fn CookTextures(self: *Cooker, allocator: std.mem.Allocator) !void {

        _ = self;
        _ = allocator;


        var dir = try std.fs.cwd().openDir("assets/src/textures", .{ .iterate = true });
        defer dir.close();

        var it = dir.iterate();
        while (try it.next()) |entry| {
            if (entry.kind != .file) continue;

            if (std.mem.endsWith(u8, entry.name, ".png")) {
                //std.log.info("Found PNG: {s}/{s}", .{ dir_path, entry.name });
            }
        }



        //try std.fs.cwd().makePath("zig-out/textures");

       // const dst_path = try std.fmt.allocPrint(
         //   allocator,
          //  "zig-out/textures/{s}",
          //  "",
       // );

       // defer allocator.free(dst_path);
    }
};
pub fn sleepMs(ms: u64) void {
    const ns = ms * std.time.ns_per_ms;
    std.posix.nanosleep(ns, 0);
}
pub const Atlas = struct {
    width: u32 = 0,
    height: u32 = 0,
    pixels: ?[]u8 = undefined,
    cursor_x: u32 = 0,
    cursor_y: u32 = 0,
    row_h: u32 = 0,
};

pub fn AddImageToAtlas(
    atlas: *Atlas,
    allocator: std.mem.Allocator,
    path: []const u8,
) !void {

    const file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const file_size = try file.getEndPos();

    const read_buf = try allocator.alloc(u8, file_size);
    defer allocator.free(read_buf);

    _ = try file.readAll(read_buf);

    // ---- load image ----
    var img = try zigimg.Image.fromFilePath(
        allocator,
        path,
        read_buf,
    );
    defer img.deinit(allocator);

    // Force RGBA8 (4 × u8 = 32 bits)
    try img.convert(allocator, .rgba32);

    const img_w: u32 = @intCast(img.width);
    const img_h: u32 = @intCast(img.height);

    // Allocate atlas pixel buffer if needed
    if (atlas.pixels == null) {
        atlas.width = 1024;
        atlas.height = 1024;
        atlas.pixels = try allocator.alloc(u8, atlas.width * atlas.height * 4);
        @memset(atlas.pixels.?, 0);
    }

    // Simple row-based packing
    if (atlas.cursor_x + img_w > atlas.width) {
        atlas.cursor_x = 0;
        atlas.cursor_y += atlas.row_h;
        atlas.row_h = 0;
    }

    if (atlas.cursor_y + img_h > atlas.height)
        return error.AtlasFull;

    const src_pixels = img.pixels.rgba32;
    const src_bytes = std.mem.sliceAsBytes(src_pixels);

    // Copy rows
    for (0..img_h) |row| {
        const dst = ((atlas.cursor_y + row) * atlas.width + atlas.cursor_x) * 4;
        const src = row * img_w * 4;

        @memcpy(
            atlas.pixels.?[dst .. dst + img_w * 4],
            src_bytes[src .. src + img_w * 4],
        );
    }

    atlas.row_h = @max(atlas.row_h, img_h);
    atlas.cursor_x += img_w;
}

// ********************************* TEXTURES ****************************************
// GOAL #1: Traverse PNG files in textures (Update if a newly added PNG file is there)
// GOAL #2: Place PNG files into a atlas (if there is one)
// GOAL #3: Convert Atlas to KTX2
// GOAL #4: Replace or add Atlas into the cooked textures folder.
//
//
// ********************************* SHADERS *****************************************

pub fn main() !void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    std.log.info("asset cooker has started", .{});

    var texture_notifier = try notify.Inotify.init("assets/src/textures");
    var shader_notifier = try notify.Inotify.init("assets/src/shaders");
    defer texture_notifier.deinit();
    defer shader_notifier.deinit();

    var cooker = Cooker{};
    var file: std.fs.File = undefined;
    

     file = std.fs.cwd().openFile("assets/cooked/atlases/manifest.json", .{}) catch |err| switch (err){
        error.FileNotFound => blk: {
            try std.fs.cwd().makePath(
                std.fs.path.dirname("assets/cooked/atlases/manifest.json").?
            );

            var new_file = try std.fs.cwd().createFile(
                "assets/cooked/atlases/manifest.json",
                .{ .truncate = true },
            );

            const json_text =
                \\{
                \\  "version": 1,
                \\  "atlases": []
                \\}
            ;

            try new_file.writeAll(json_text);
            break :blk new_file; // 🔑 return fs.File
        },
        else => return err,

    };

    defer file.close();
    

    while(true) {

        try texture_notifier.wait(300);
        try shader_notifier.wait(0);

        texture_notifier.poll(&cooker.time_to_cook_textures);
        shader_notifier.poll(&cooker.time_to_cook_shaders);

        if (cooker.time_to_cook_textures) {
            std.log.info("Cooking textures", .{});
            cooker.time_to_cook_textures = false;
            try cooker.CookTextures(allocator);
        }

        if (cooker.time_to_cook_shaders) {
            std.log.info("Cooking shaders", .{});
            cooker.time_to_cook_shaders = false;
        }

    }

}

pub fn MakeAtlas() void{

   // const atlas = 
   

   // const allocated_image = try text.CreateTextureImage(renderer, core, allocator, color_space, path_z);
  //  try text.CreateTextureImageView(core, allocated_image);

}




fn ConvertToKTX2(
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
