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

pub const AtlasEntry = struct {
    id: u32,
    path: []const u8,
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

pub fn ReadManifest(allocator: std.mem.Allocator) !std.json.Parsed(Manifest){

    const file = try std.fs.cwd().openFile("assets/cooked/atlases/manifest.json", .{});
    defer file.close();

    const file_size = try file.getEndPos();
    const bytes = try allocator.alloc(u8, file_size);

    _ = try file.readAll(bytes);

    return std.json.parseFromSlice(
        Manifest,
        allocator,
        bytes,
        .{ .ignore_unknown_fields = true },
    );

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
    path: []const u8,
    from_path: []const u8,
    id: usize,
) !void{

    if (manifest.atlases.len != id){
        manifest.atlases[id].rev += 1;
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
        .from_path = try allocator.dupe(u8, from_path),
        .rev = 1,
    };

    //allocator.free(manifest.atlases);

    manifest.atlases = new_atlases;

}
