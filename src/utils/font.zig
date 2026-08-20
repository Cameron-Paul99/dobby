const std = @import("std");
const utils = @import("utils.zig");
const ui = @import("ui.zig");
const math = @import("math.zig");
const atlas_mod = @import("atlas.zig");

pub const font_tmp = "projects/{s}/cooked/fonts/manifest.tmp";
pub const font_path = "projects/{s}/cooked/fonts/manifest.json";

pub const Position = struct { x: f32, y: f32 };

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
    size: f32,
};

pub const FontInfo = struct {
    atlas_id: u32,
    glyphs: [128]GlyphInfo, // ASCII range
    line_height: f32,
    size: f32,
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



pub fn ParseFnt(contents: []const u8, image_w: f32, image_h: f32) struct { glyphs: [128]GlyphInfo, line_height: f32, size: f32 } {
    var glyphs = [_]GlyphInfo{.{}} ** 128;
    var line_height: f32 = 0;
    var size: f32 = 0;
    var lines = std.mem.splitScalar(u8, contents, '\n');
    while (lines.next()) |line| {
        if (std.mem.startsWith(u8, line, "common ")) {
            line_height = parseField(line, "lineHeight=");
        }
        if (std.mem.startsWith(u8, line, "info ")) {
            size = parseField(line, "size=");
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
    return .{ .glyphs = glyphs, .line_height = line_height, .size = size};
}



// TODO: Find a solution so we can avoid passing in anytype. I'm thinking another struct




pub fn WriteGlyphsAt(
    ctx: anytype,
    start_index: usize, 
    txt: [*:0]const u8, 
    pos: math.Vec2,
    scale: math.Vec2,
    color: struct {r: f32, g: f32, b: f32, a: f32},
    screen_h: f32,
    screen_w: f32,
    font: FontInfo,
    anchor: ui.Anchor,
) usize {

    const text_w = MeasureTxt(std.mem.span(txt), font.glyphs);
    const text_h = MeasureTxtHeight(std.mem.span(txt), font.line_height);

    const anchor_cal = switch (anchor) {
        .center => Center(screen_w, screen_h, text_w, text_h, pos),
        .top_left => TopLeft(pos),
        .top_right => TopRight(screen_w, text_w, pos), 
        .bottom_left => BottomLeft(screen_h, text_h, pos),  
        .bottom_right => BottomRight(screen_w, screen_h, text_w, text_h, pos), 
    };

    const x = anchor_cal.x;
    const y = anchor_cal.y;

    var cursor_x = x;
    var write_index = start_index;

    for (std.mem.span(txt)) |l| {
        const glyph = for (font.glyphs) |g| {
            if (l == g.letter) break g;
        } else continue;

        const uv_min_x = glyph.uv_x;
        const uv_min_y = glyph.uv_y;
        const uv_max_x = glyph.uv_x + glyph.uv_w;
        const uv_max_y = glyph.uv_y + glyph.uv_h;
        const atlas_w: f32 = 256.0;
        const atlas_h: f32 = 128.0;
        const glyph_w = glyph.uv_w * atlas_w * scale.x;
        const glyph_h = glyph.uv_h * atlas_h * scale.y;
        const offset_x = glyph.offset_x * scale.x;
        const offset_y = glyph.offset_y * scale.y;

        const VertT = @TypeOf(ctx.ui_components[0]);

        const verts = [4]VertT{
            .{ .pos = .{ cursor_x + offset_x, y + offset_y }, .uv = .{ uv_min_x, uv_min_y }, .color = .{ color.r, color.g, color.b, color.a }, .atlas_id = font.atlas_id },
            .{ .pos = .{ cursor_x + offset_x + glyph_w, y + offset_y }, .uv = .{ uv_max_x, uv_min_y }, .color = .{ color.r, color.g, color.b, color.a }, .atlas_id = font.atlas_id },
            .{ .pos = .{ cursor_x + offset_x + glyph_w, y + offset_y + glyph_h }, .uv = .{ uv_max_x, uv_max_y }, .color = .{ color.r, color.g, color.b, color.a }, .atlas_id = font.atlas_id },
            .{ .pos = .{ cursor_x + offset_x, y + offset_y + glyph_h }, .uv = .{ uv_min_x, uv_max_y }, .    color = .{ color.r, color.g, color.b, color.a }, .atlas_id = font.atlas_id },
        };

        for (verts) |v| {
            if (write_index >= ctx.ui_components.len) {
                std.log.warn("UI vertex buffer full, dropping vertex", .{});
                break;
            }
            ctx.ui_components[write_index] = v;
            write_index += 1;
        }

        cursor_x += glyph.advance * scale.x;
    }

    return write_index - start_index;
}

fn MeasureTxt(txt: []const u8, glyphs: [128]GlyphInfo) f32{

    var total_w: f32 = 0;
    for (txt) |c| {
        if (c >= 128) continue;
        total_w += glyphs[c].advance;
    }
    return total_w;

}

fn MeasureTxtHeight(txt: []const u8, line_height: f32) f32 {

    var lines: f32 = 1;
    for (txt) |c| {
        if (c == '\n') lines += 1;
    }
    return lines * line_height;
}



fn Center (
    screen_w: f32,
    screen_h: f32,
    text_w: f32,
    text_h: f32,
    pos: math.Vec2,
) Position {
    return .{.x = (screen_w - text_w) / 2 + pos.x, .y = (screen_h - text_h) / 2 + pos.y};
}

fn TopLeft (
    pos: math.Vec2,
) Position {
    return .{.x = pos.x, .y = pos.y};
}

fn TopRight (
    screen_w: f32,
    text_w: f32,
    pos: math.Vec2,
) Position {
    return .{.x = screen_w - text_w - pos.x, .y = pos.y};
}

fn BottomRight (
    screen_w: f32,
    screen_h: f32,
    text_w: f32,
    text_h: f32,
    pos: math.Vec2,
) Position {
    return .{.x = screen_w - text_w - pos.x, .y = screen_h - text_h - pos.y};
}

fn BottomLeft (
    screen_h: f32,
    text_h: f32,
    pos: math.Vec2,
) Position {
    return .{.x = pos.x, .y = screen_h - text_h - pos.y};
}


