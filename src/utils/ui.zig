const math = @import("math.zig");
const std = @import("std");
const atlas_mod = @import("atlas.zig");
const font_mod = @import("font.zig");

pub const Anchor = enum { center, top_left, top_right, bottom_left, bottom_right };

pub var fonts: [10]font_mod.FontInfo = undefined; 

pub const UiTextHandle = struct {
    start: u32,
    count: u32,
};

pub const UiTextEntry = struct {
    id: u32,
    start: usize,
    count: usize,
    txt: [*:0]const u8,
    pos: math.Vec2,
    anchor: Anchor,
};

pub fn Init (
    ctx: anytype,
) void {

    const fontInfo = atlas_mod.GetFontFromAtlas(
        ctx.io, "Inter", ctx.proj, ctx.allocator,
    ) catch |err| {
        std.log.err("GetFontFromAtlas failed: {}", .{err});
        return;
    };
    const font = &(fontInfo orelse return);

    fonts[0] = font.*;
    
}


pub fn UpdateText(
    ctx: anytype, 
    ui_text_entries: []UiTextEntry,
    screen_h: f32,
    screen_w: f32,
) void {

    for (ui_text_entries) |*entry| {
        const new_count = font_mod.WriteGlyphsAt(
            ctx, 
            entry.start, 
            entry.txt, 
            entry.pos,
            screen_h,
            screen_w,
            fonts[0],
            entry.anchor,
        );
        entry.count = @intCast(new_count); // in case glyph count changed (shouldn't for same string, but safe)
    }
}
