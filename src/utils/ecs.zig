const std = @import("std");


pub const Entity = u32;

pub const L2_BITS: u32 = 64;    
pub const L1_BITS: u32 = 64;          

pub const L2_BLOCK = u64;
pub const L1_BLOCK = u64;

inline fn popcount(x: u64) u32 {
    return @intCast(u32, @popCount(x));
}

inline fn tzcnt(x: u64) u32 {
    return @intCast(u32, @ctz(x));
}
