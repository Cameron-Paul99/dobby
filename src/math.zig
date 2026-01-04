const std = @import("std");

// -----------------------------------------------------------------------------
// Compatibility / utils
// -----------------------------------------------------------------------------
pub inline fn abs(f: anytype) @TypeOf(f){

    const type_info = @typeInfo(@TypeOf(f));
    if (type_info != .float and type_info != .int){
        @compileError("Expected integer or floating point type");
    }

    return if (f < 0) -f else f;
}

pub inline fn clamp(x: f32, lo: f32, hi: f32) f32 {
    return @min(@max(x, lo), hi);
}

pub inline fn lerp(a: f32, b: f32, t: f32) f32 {
    return a + t * (b - a);
}
// -----------------------------------------------------------------------------
// CPU vector types (NOT std140 padded). Use GPU structs for buffers.
// -----------------------------------------------------------------------------

pub const Vec2 = struct{
    x: f32,
    y: f32,

    pub const ZERO = Make(0.0, 0.0);

    pub inline fn Make(x: f32, y: f32) Vec2{
        return .{.x = x, .y = y};
    }

    pub inline fn Add(a: Vec2, b: Vec2) Vec2{
        return .{.x = a.x + b.x, .y = a.y + b.y};
    }

    pub inline fn Mul(a: Vec2, s: f32) Vec2 {
        return .{.x = a.x * s, .y = a.y * s};
    }

    pub inline fn Dot(a: Vec2, b: Vec2) f32 {
        return a.x * b.x + a.y * b.y;
    }

    pub inline fn Sub(a: Vec2, b: Vec2) Vec2 {
        return .{.x = a.x - b.x, .y = a.y - b.y};
    }

    pub inline fn Div(a: Vec2, s: f32) Vec2{
        return .{.x = a.x / s, .y = a.y / s};
    }

    pub inline fn LengthSquared(a: Vec2) f32{
        return Dot(a, a);
    }

    pub inline fn Length(a: Vec2) f32{
        return @sqrt(LengthSquared(a));
    }

    pub inline fn Normalized(a: Vec2) Vec2{
        const len = Length(a);
        return Div(a, len);
    }

    pub inline fn Perp(v: Vec2) Vec2 {
        return .{.x = -v.y, .y = v.x};
    }

    pub inline fn ToVec3(self: Vec2, z: f32) Vec3{
        return .{.x = self.x, .y = self.y, .z = z};
    }

    pub inline fn IsPerpendicular(a: Vec2, b: Vec2, eps: f32) bool{
        // Zero length is non perpendicular
        const aa = LengthSquared(a);
        const bb = LengthSquared(b);
        if (aa == 0 or bb == 0) return false;

        const d = Dot(a, b);
        return @abs(d) <= eps * @sqrt(aa * bb);
    }
    
    pub inline fn IsPerpendicularUnit(a: Vec2, b: Vec2, eps: f32) bool{
        return @abs(Dot(a,b)) <= eps;
    }
    
    pub inline fn Cross(a: Vec2, b: Vec2) f32 {
        return a.x * b.y - a.y * b.x;
    }
    
    pub inline fn IsParallel(a: Vec2, b: Vec2, eps: f32) bool{
        // Zero length is not parallel
        const aa = LengthSquared(a);
        const bb = LengthSquared(b);
        if (aa == 0 or bb == 0) return false;

        const c = Cross(a, b);
        return @abs(c) <= eps * @sqrt(aa * bb); 
    }

    pub inline fn IsParallelUnit(a: Vec2, b: Vec2, eps: f32) bool{
        return @abs(Cross(a, b)) <= eps;
    }

    pub inline fn IsSameDirection(a: Vec2, b: Vec2, eps: f32) bool{
        return IsParallel(a, b, eps) and Dot(a, b) > 0;
    }

    pub inline fn IsOppositeDirection(a: Vec2, b: Vec2, eps: f32) bool{
        return IsParallel(a, b, eps) and Dot(a, b) < 0;
    }

};

pub const Vec3 = struct {


};

pub const Vec4 = struct {


};

pub const Mat4 = struct {



};
