const std = @import("std");
const zigimg = @import("zigimg");

// GOAL is to cook png files and then add to renderer
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
