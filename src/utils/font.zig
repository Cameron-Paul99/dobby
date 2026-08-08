const std = @import("std");
const utils = @import("utils.zig");

pub const font_tmp = "projects/{s}/cooked/fonts/manifest.tmp";
pub const font_path = "projects/{s}/cooked/fonts/manifest.json";

pub const FontManifest = struct {
    version: u32,
    fonts: []Font,
};


pub const GlyphInfo = struct {
    letter: u8 = 0,
    uv_x: f32 = 0,
    uv_y: f32 = 0,
    uv_w: f32 = 0,
    uv_h: f32 = 0,
    offset_x: f32 = 0,
    offset_y: f32 = 0,
    advance: f32 = 0,
};

pub const Font = struct {
    name: []const u8, 
    path: []const u8,
    glyphs: [128]GlyphInfo, // ASCII range
    line_height: f32,
};

pub const ParsedFontManifest = struct {
    parsed: std.json.Parsed(FontManifest),
    buffer: []u8,

    pub fn deinit(self: *ParsedFontManifest, allocator: std.mem.Allocator) void {
        self.parsed.deinit();
        allocator.free(self.buffer);
    }
};

pub fn ReadFontManifest(
    io: std.Io,
    proj: utils.Project,
    allocator: std.mem.Allocator,
) !ParsedFontManifest {

    const manifest_path = try std.fmt.allocPrint(
        allocator,
        font_path,
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
        FontManifest,
        allocator,
        bytes,
        .{ .ignore_unknown_fields = true },
    );

    return .{
        .parsed = parsed,
        .buffer = bytes,
    };

}

pub fn parseField(line: []const u8, field: []const u8) f32 {
    const start = std.mem.indexOf(u8, line, field) orelse return 0;
    const value_start = start + field.len;
    var end = value_start;
    while (end < line.len and (std.ascii.isDigit(line[end]) or line[end] == '-')) : (end += 1) {}
    const value_str = line[value_start..end];
    return std.fmt.parseFloat(f32, value_str) catch 0;
}



pub fn ParseFnt(contents: []const u8, image_w: f32, image_h: f32) struct { glyphs: [128]GlyphInfo, line_height: f32 } {
    var glyphs = [_]GlyphInfo{.{}} ** 128;
    var line_height: f32 = 0;
    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "common ")) {
            line_height = parseField(line, "lineHeight=");
        }
        if (!std.mem.startsWith(u8, line, "char id=")) continue;
        const id: u8 = @intFromFloat(parseField(line, "id="));
        if (id >= 128) continue;
        glyphs[id] = GlyphInfo{
            .letter = id,
            .uv_x = parseField(line, "x=") / image_w,
            .uv_y = parseField(line, "y=") / image_h,
            .uv_w = parseField(line, "width=") / image_w,
            .uv_h = parseField(line, "height=") / image_h,
            .offset_x = parseField(line, "xoffset="),
            .offset_y = parseField(line, "yoffset="),
            .advance = parseField(line, "xadvance="),
        };
    }
    return .{ .glyphs = glyphs, .line_height = line_height };
}
