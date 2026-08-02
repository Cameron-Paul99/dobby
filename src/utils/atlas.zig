const std = @import("std");
const utils = @import("utils.zig");

pub const AtlasAliasId_u32 = u32;
pub const atlas_path = "projects/{s}/cooked/atlases/manifest.json";
pub const atlas_tmp = "projects/{s}/cooked/atlases/manifest.tmp"; 

pub const Atlas = struct {
    width: u32 = 0,
    height: u32 = 0,
    pixels: ?[]u8 = null,
    cursor_x: u32 = 0,
    cursor_y: u32 = 0,
    row_h: u32 = 0,
};

pub const AtlasAsset = struct {
    id: AtlasAliasId_u32,
    path: []const u8,
    version_hash: u64,
};

pub const AtlasImage = struct {
    name: []const u8,
    uv_min: [2]f32,
    uv_max: [2]f32,
};

pub const AtlasEntry = struct {
    id: u32,
    path: []const u8,
    atlas_imgs: []AtlasImage,
    from_path: []const u8,
    rev: u32,
};

pub const Manifest = struct {
    version: u32,
    atlases: []AtlasEntry,
};

pub const GlyphInfo = struct {
    uv_x: f32,
    uv_y: f32,
    uv_w: f32,
    uv_h: f32,
    offset_x: f32,
    offset_y: f32,
    advance: f32,
};

pub const Font = struct {
    atlas_id: u32,
    glyphs: [128]GlyphInfo, // ASCII range
    line_height: f32,
};

pub const ParsedManifest = struct {
    parsed: std.json.Parsed(Manifest),
    buffer: []u8,

    pub fn deinit(self: *ParsedManifest, allocator: std.mem.Allocator) void {
        self.parsed.deinit();
        allocator.free(self.buffer);
    }
};

pub fn ReadManifest(
    io: std.Io,
    proj: utils.Project, 
    allocator: std.mem.Allocator
) !ParsedManifest{

    const manifest_path = try std.fmt.allocPrint(
        allocator,
        atlas_path,
        .{ proj.name },
    );
    defer allocator.free(manifest_path); 

    const file = try std.Io.Dir.cwd().openFile(
        io, 
        manifest_path, 
        .{}
    );
    defer file.close(io);

    const file_size = try file.length(io); 
    const bytes = try allocator.alloc(u8, file_size);
    errdefer allocator.free(bytes);  

    _ = try file.readPositionalAll(io, bytes, 0); 

    const parsed = try std.json.parseFromSlice(
        Manifest,
        allocator,
        bytes,
        .{ .ignore_unknown_fields = true },
    );

    return .{
        .parsed = parsed,
        .buffer = bytes,
    };

}
pub fn ReadManifestGame(
    io: std.Io,
    proj: []const u8, 
    allocator: std.mem.Allocator
) !ParsedManifest{

    const manifest_path = try std.fmt.allocPrint(
        allocator,
        atlas_path,
        .{ proj },
    );
    defer allocator.free(manifest_path); 

    const file = try std.Io.Dir.cwd().openFile(
        io, 
        manifest_path, 
        .{}
    );
    defer file.close(io);

    const file_size = try file.length(io); 
    const bytes = try allocator.alloc(u8, file_size);
    errdefer allocator.free(bytes);  

    _ = try file.readPositionalAll(io, bytes, 0); 

    const parsed = try std.json.parseFromSlice(
        Manifest,
        allocator,
        bytes,
        .{ .ignore_unknown_fields = true },
    );

    return .{
        .parsed = parsed,
        .buffer = bytes,
    };

}
pub fn WriteManifest(
    io: std.Io,
    proj: utils.Project , 
    manifest: Manifest, 
    allocator: std.mem.Allocator
) !void {

    const manifest_path = try std.fmt.allocPrint(
        allocator,
        atlas_path,
        .{ proj.name },
    );
    defer allocator.free(manifest_path); 
    //_ = allocator;
    const tmp_path = try std.fmt.allocPrint(
        allocator,
        atlas_tmp,
        .{ proj.name },
    );
    defer allocator.free(tmp_path);

    const json_text = try std.fmt.allocPrint(
        allocator,
        "{f}",
        .{ std.json.fmt(manifest, .{ .whitespace = .indent_2 }) },
    );
    defer allocator.free(json_text);

    var tmp_file = try std.Io.Dir.cwd().createFile(io, tmp_path, .{ .truncate = true });
    defer tmp_file.close(io);

    try tmp_file.writeStreamingAll(io, json_text);
    try tmp_file.sync(io);
    const cwd = std.Io.Dir.cwd();
    try std.Io.Dir.rename(cwd, tmp_path, cwd, manifest_path, io); 
}

pub fn AddAtlasToManifest(
    allocator: std.mem.Allocator,
    manifest: *Manifest,
    atlas_imgs: []AtlasImage,
    path: []const u8,
    from_path: []const u8,
    id: usize,
) !void{

    if (manifest.atlases.len != id){
        manifest.atlases[id].rev += 1;
        manifest.atlases[id].atlas_imgs = atlas_imgs;
        return;
    }

    const new_len = manifest.atlases.len + 1;

    var new_atlases = try allocator.alloc(AtlasEntry, new_len);

    @memcpy(
        new_atlases[0..manifest.atlases.len],
        manifest.atlases,
    );

    new_atlases[manifest.atlases.len] = .{
        .id = @intCast(manifest.atlases.len),
        .path = try allocator.dupe(u8, path),
        .atlas_imgs = atlas_imgs,
        .from_path = try allocator.dupe(u8, from_path),
        .rev = 1,
    };

    manifest.atlases = new_atlases;

}

pub fn ComputeUVs(
    atlas: *Atlas, 
    img_h: u32, 
    img_w: u32,
    cursor_x: u32,
    cursor_y: u32,
    name: []const u8,
    ) AtlasImage{

    const aw = @as(f32, @floatFromInt(atlas.width));
    const ah = @as(f32, @floatFromInt(atlas.height));

    const fx = @as(f32, @floatFromInt(cursor_x));
    const fy = @as(f32, @floatFromInt(cursor_y));
    const fw = @as(f32, @floatFromInt(img_w));
    const fh = @as(f32, @floatFromInt(img_h));

    const uv_min = .{
        fx / aw,
        fy / ah,
    };

    const uv_max = .{
        (fx + fw) / aw,
        (fy + fh) / ah,
    };

    return .{
        .name = name,
        .uv_min = uv_min,
        .uv_max = uv_max,
    };

}

pub fn GetImageFromAtlas(
    io: std.Io,
    atlas_id: usize,
    name: []const u8,
    proj: utils.Project,
    allocator: std.mem.Allocator,
) !?AtlasImage {

    var manifest = try ReadManifest(io, proj, allocator);
    defer manifest.deinit(allocator);

    const atlas = &manifest.parsed.value.atlases[atlas_id];

    for (atlas.atlas_imgs) |entry| {
        if (std.mem.eql(u8, name, entry.name)) {
            return AtlasImage{
                .name = try allocator.dupe(u8, entry.name),
                .uv_min = entry.uv_min,
                .uv_max = entry.uv_max,
            };
        }
    }

    return null;
}

pub fn GetImageFromAtlasGame(
    io: std.Io,
    atlas_id: usize,
    name: []const u8,
    proj: []const u8,
    allocator: std.mem.Allocator,
) !?AtlasImage {

    var manifest = try ReadManifestGame(io, proj, allocator);
    defer manifest.deinit(allocator);

    const atlas = &manifest.parsed.value.atlases[atlas_id];

    for (atlas.atlas_imgs) |entry| {
        if (std.mem.eql(u8, name, entry.name)) {
            return AtlasImage{
                .name = try allocator.dupe(u8, entry.name),
                .uv_min = entry.uv_min,
                .uv_max = entry.uv_max,
            };
        }
    }

    return null;
}
