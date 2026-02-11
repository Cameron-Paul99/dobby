const std = @import("std");
const Self = @This();

pub const Entity = u32;

pub const L2_BITS_u32: u32 = 64;    
pub const L1_BITS_u32: u32 = 64;          

pub const L2_BLOCK_u64 = u64;
pub const L1_BLOCK_u64 = u64;

inline fn popcount(x: u64) u32 {
    return @intCast(@popCount(x));
}

inline fn tzcnt(x: u64) u32 {
    return @intCast(@ctz(x));
}

l1: []L1_BLOCK_u64,
l2: []L2_BLOCK_u64,
allocator: std.mem.Allocator,

pub fn init(max_entries: u32, allocator: std.mem.Allocator) !Self {
    const l2_blocks = (max_entries + L2_BITS_u32 - 1) / L2_BITS_u32;
    const l1_blocks = (l2_blocks + L1_BITS_u32 - 1) / L1_BITS_u32;
    return .{
        .l1 = try allocator.alloc(L1_BLOCK_u64, l1_blocks),
        .l2 = try allocator.alloc(L2_BLOCK_u64, l2_blocks),
        .allocator = allocator,
    };
}

pub fn deinit(self: *Self) !void{
     self.allocator.free(self.l1);
     self.allocator.free(self.l2);
}

pub fn Set(self: *Self, entity: Entity) void {
    const l2_index: u32 = entity / L2_BITS_u32;

    const bit: u6 = @intCast(entity % L2_BITS_u32);

    self.l2[l2_index] |= (@as(u64, 1) << bit);

    const l1_index: u32 = l2_index / L1_BITS_u32;
    const l1_bit: u6 = @intCast(l2_index % L1_BITS_u32);

    self.l1[l1_index] |= (@as(u64, 1) << l1_bit);
}


pub fn Clear(self: *Self, entity: Entity) void{
    const l2_index = entity / L2_BITS_u32;
    const bit = entity % L2_BITS_u32;

    self.l2[l2_index] &= ~(@as(u64, 1) << bit);
    
    const l1_index = l2_index / L1_BITS_u32;
    const l1_bit = l2_index % L1_BITS_u32;

    self.l1[l1_index] &= ~(@as(u64, 1) << l1_bit);
}

pub fn testBit(self: *Self, entity: Entity) bool { 
    const l2_idx = entity / L2_BITS_u32; 
    const bit = entity % L2_BITS_u32; 
    return (self.l2[l2_idx] & (@as(u64, 1) << bit)) != 0; 
}
