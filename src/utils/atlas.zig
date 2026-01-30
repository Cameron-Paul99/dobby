const std = @import("std");

pub const AtlasAliasId_u32 = u32;

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

pub const ParsedManifest = struct {
    parsed: std.json.Parsed(Manifest),
    buffer: []u8,

    pub fn deinit(self: *ParsedManifest, allocator: std.mem.Allocator) void {
        self.parsed.deinit();
        allocator.free(self.buffer);
    }
};

pub fn ReadManifest(allocator: std.mem.Allocator) !ParsedManifest{

    const file = try std.fs.cwd().openFile("assets/cooked/atlases/manifest.json", .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const bytes = try allocator.alloc(u8, file_size);

    _ = try file.readAll(bytes);

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

pub fn WriteManifest(manifest: Manifest, allocator: std.mem.Allocator) !void {
    
    //_ = allocator;
    var file = try std.fs.cwd().createFile("assets/cooked/atlases/manifest.json", .{ .truncate = true });
    defer file.close();

    const json_text = try std.fmt.allocPrint(
        allocator,
        "{f}",
        .{ std.json.fmt(manifest, .{ .whitespace = .indent_2 }) },
    );
    defer allocator.free(json_text);

    try file.writeAll(json_text);

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
    atlas_id: usize,
    name: []const u8,
    allocator: std.mem.Allocator,
) !?AtlasImage {

    var manifest = try ReadManifest(allocator);
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
