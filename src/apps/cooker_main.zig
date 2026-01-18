const std = @import("std");
const zigimg = @import("zigimg");

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

pub fn main() void {

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    _ = allocator;

    std.log.info("asset cooker has started", .{});

   // while(true) {
      //  try cookShaders();
      //  try cookTextures();

    //    std.time.sleep(300 * std.time.ns_per_ms);
    //}

}

fn cookShaders() void {

}

fn cookTextures() void {



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
