const std = @import("std");

// -----------------------------------------------------------------------------
// Compatibility / utils
// -----------------------------------------------------------------------------
pub inline fn Abs(f: anytype) @TypeOf(f){

    const type_info = @typeInfo(@TypeOf(f));
    if (type_info != .float and type_info != .int){
        @compileError("Expected integer or floating point type");
    }

    return if (f < 0) -f else f;
}

pub inline fn Clamp(x: f32, lo: f32, hi: f32) f32 {
    return @min(@max(x, lo), hi);
}

pub inline fn Lerp(a: f32, b: f32, t: f32) f32 {
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
        const len_sq = LengthSquared(a);
        if (len_sq == 0) return ZERO;
        return Div(a, @sqrt(len_sq));
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
    
    pub inline fn CrossScalar(a: Vec2, b: Vec2) f32 {
        return a.x * b.y - a.y * b.x;
    }
    
    pub inline fn IsParallel(a: Vec2, b: Vec2, eps: f32) bool{
        // Zero length is not parallel
        const aa = LengthSquared(a);
        const bb = LengthSquared(b);
        if (aa == 0 or bb == 0) return false;

        const c = CrossScalar(a, b);
        return @abs(c) <= eps * @sqrt(aa * bb); 
    }

    pub inline fn IsParallelUnit(a: Vec2, b: Vec2, eps: f32) bool{
        return @abs(CrossScalar(a, b)) <= eps;
    }

    pub inline fn IsSameDirection(a: Vec2, b: Vec2, eps: f32) bool{
        return IsParallel(a, b, eps) and Dot(a, b) > 0;
    }

    pub inline fn IsOppositeDirection(a: Vec2, b: Vec2, eps: f32) bool{
        return IsParallel(a, b, eps) and Dot(a, b) < 0;
    }

};

pub const Vec3 = struct {
    x: f32,
    y: f32,
    z: f32,

    pub const ZERO = Make(0.0, 0.0, 0.0);

    pub inline fn Make(x: f32, y: f32, z: f32) Vec3{
        return .{.x = x, .y = y, .z = z};
    }

    pub inline fn Add(a: Vec3, b: Vec3) Vec3{
        return .{.x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z};
    }

    pub inline fn Mul(a: Vec3, s: f32) Vec3 {
        return .{.x = a.x * s, .y = a.y * s, .z = a.z * s};
    }

    pub inline fn Dot(a: Vec3, b: Vec3) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z;
    }

    pub inline fn Sub(a: Vec3, b: Vec3) Vec3 {
        return .{.x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z};
    }

    pub inline fn Div(a: Vec3, s: f32) Vec3{
        return .{.x = a.x / s, .y = a.y / s, .z = a.z / s};
    }

    pub inline fn LengthSquared(a: Vec3) f32{
        return Dot(a, a);
    }

    pub inline fn Length(a: Vec3) f32{
        return @sqrt(LengthSquared(a));
    }

    pub inline fn Normalized(a: Vec3) Vec3{
        const len_sq = LengthSquared(a);
        if (len_sq == 0) return ZERO;
        return Div(a, @sqrt(len_sq));
    }

    pub inline fn ToPoint4(p: Vec3) Vec4 {
        return .{ .x = p.x, .y = p.y, .z = p.z, .w = 1.0 };
    }

    pub inline fn ToDir4(d: Vec3) Vec4 {
        return .{ .x = d.x, .y = d.y, .z = d.z, .w = 0.0 };
    }

    pub inline fn IsPerpendicular(a: Vec3, b: Vec3, eps: f32) bool{
        // Zero length is non perpendicular
        const aa = LengthSquared(a);
        const bb = LengthSquared(b);
        if (aa == 0 or bb == 0) return false;

        const d = Dot(a, b);
        return @abs(d) <= eps * @sqrt(aa * bb);
    }
    
    pub inline fn IsPerpendicularUnit(a: Vec3, b: Vec3, eps: f32) bool{
        return @abs(Dot(a,b)) <= eps;
    }
    
    pub inline fn Cross(a: Vec3, b: Vec3) Vec3 {
        return .{
            .x = a.y * b.z - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
        };
    }
    
    pub inline fn IsParallel(a: Vec3, b: Vec3, eps: f32) bool{
        // Zero length is not parallel
        const aa = LengthSquared(a);
        const bb = LengthSquared(b);
        if (aa == 0 or bb == 0) return false;

        const c = Cross(a, b);
        return LengthSquared(c) <= (eps * eps) * aa * bb; 
    }

    pub inline fn IsParallelUnit(a: Vec3, b: Vec3, eps: f32) bool{
        return LengthSquared(Cross(a, b)) <= eps * eps;    
    }

    pub inline fn IsSameDirection(a: Vec3, b: Vec3, eps: f32) bool{
        return IsParallel(a, b, eps) and Dot(a, b) > 0;
    }

    pub inline fn IsOppositeDirection(a: Vec3, b: Vec3, eps: f32) bool{
        return IsParallel(a, b, eps) and Dot(a, b) < 0;
    }

};

pub const Vec4 = struct {
    x: f32,
    y: f32,
    z: f32,
    w: f32,

    pub const ZERO = Make(0.0, 0.0, 0.0, 0.0);

    pub inline fn Make(x: f32, y: f32, z: f32, w: f32) Vec4{
        return .{.x = x, .y = y, .z = z, .w = w};
    }

    pub inline fn Add(a: Vec4, b: Vec4) Vec4{
        return .{.x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z, .w = a.w + b.w};
    }

    pub inline fn Mul(a: Vec4, s: f32) Vec4 {
        return .{.x = a.x * s, .y = a.y * s, .z = a.z * s, .w = a.w * s};
    }

    pub inline fn Dot(a: Vec4, b: Vec4) f32 {
        return a.x * b.x + a.y * b.y + a.z * b.z + a.w * b.w;
    }

    pub inline fn Sub(a: Vec4, b: Vec4) Vec4 {
        return .{.x = a.x - b.x, .y = a.y - b.y, .z = a.z - b.z, .w = a.w - b.w};
    }

    pub inline fn Div(a: Vec4, s: f32) Vec4{
        return .{.x = a.x / s, .y = a.y / s, .z = a.z / s, .w = a.w / s};
    }

    pub inline fn LengthSquared(a: Vec4) f32{
        return Dot(a, a);
    }

    pub inline fn Length(a: Vec4) f32{
        return @sqrt(LengthSquared(a));
    }

    pub inline fn Normalized(a: Vec4) Vec4{
        const len_sq = LengthSquared(a);
        if (len_sq == 0) return ZERO;
        return Div(a, @sqrt(len_sq));
    }

    pub inline fn IsPerpendicular(a: Vec4, b: Vec4, eps: f32) bool{
        // Zero length is non perpendicular
        const aa = LengthSquared(a);
        const bb = LengthSquared(b);
        if (aa == 0 or bb == 0) return false;

        const d = Dot(a, b);
        return @abs(d) <= eps * @sqrt(aa * bb);
    }
    
    pub inline fn IsPerpendicularUnit(a: Vec4, b: Vec4, eps: f32) bool{
        return @abs(Dot(a,b)) <= eps;
    }
    
    pub inline fn CrossXYZ(a: Vec4, b: Vec4) Vec4 {
        return .{
            .x = a.y * b.z  - a.z * b.y,
            .y = a.z * b.x - a.x * b.z,
            .z = a.x * b.y - a.y * b.x,
            .w = 0,
        };
    }

    pub inline fn DotXYZ(a: Vec4, b: Vec4) f32 {
        return a.x*b.x + a.y*b.y + a.z*b.z;
    }

    pub inline fn LengthSquaredXYZ(a: Vec4) f32 {
        return DotXYZ(a, a);
    }

    
    pub inline fn IsParallel(a: Vec4, b: Vec4, eps: f32) bool{
        // Zero length is not parallel
        const aa = LengthSquaredXYZ(a);
        const bb = LengthSquaredXYZ(b);
        if (aa == 0 or bb == 0) return false;

        const c = CrossXYZ(a, b);
        return LengthSquaredXYZ(c) <= (eps * eps) * aa * bb; 
    }

    pub inline fn IsParallelUnit(a: Vec4, b: Vec4, eps: f32) bool{
        return LengthSquaredXYZ(CrossXYZ(a, b)) <= eps * eps;    
    }

    pub inline fn IsSameDirection(a: Vec4, b: Vec4, eps: f32) bool{
        return IsParallel(a, b, eps) and DotXYZ(a, b) > 0;
    }

    pub inline fn IsOppositeDirection(a: Vec4, b: Vec4, eps: f32) bool{
        return IsParallel(a, b, eps) and DotXYZ(a, b) < 0;
    }

};

pub const Mat4 = struct {
    // Columns (basis + translation)
    i: Vec4,
    j: Vec4,
    k: Vec4,
    t: Vec4,

    const Self = @This();

    pub const IDENTITY: Mat4 = Make(
        Vec4.Make(1.0, 0.0, 0.0, 0.0),
        Vec4.Make(0.0, 1.0, 0.0, 0.0),
        Vec4.Make(0.0, 0.0, 1.0, 0.0),
        Vec4.Make(0.0, 0.0, 0.0, 1.0),
    );

    pub inline fn Make(i: Vec4, j: Vec4, k: Vec4, t: Vec4) Mat4{
        return .{.i = i, .j = j, .k = k, .t = t};
    }

    pub inline fn Transposed(self: Self) Self{
        return Make(
            Vec4.Make(self.i.x, self.j.x, self.k.x, self.t.x),
            Vec4.Make(self.i.y, self.j.y, self.k.y, self.t.y),
            Vec4.Make(self.i.z, self.j.z, self.k.z, self.t.z),
            Vec4.Make(self.i.w, self.j.w, self.k.w, self.t.w),
        );
    }

    // Matrix * Vec4 (Column vector)
    pub inline fn MulVec4(m: Self, v: Vec4) Vec4 {
        return Vec4.Make(
            m.i.x * v.x + m.j.x * v.y + m.k.x * v.z + m.t.x * v.w,
            m.i.y * v.x + m.j.y * v.y + m.k.y * v.z + m.t.y * v.w,
            m.i.z * v.x + m.j.z * v.y + m.k.z * v.z + m.t.z * v.w,
            m.i.w * v.x + m.j.w * v.y + m.k.w * v.z + m.t.w * v.w,
        );
    }


    // Matrix * Matrix (Column-Major)
    pub inline fn Mul(a: Self, b: Self) Self{
        return Make(
            MulVec4(a, b.i),
            MulVec4(a, b.j),
            MulVec4(a, b.k),
            MulVec4(a, b.t),
        );
    }
    
    // Transform a point (w = 1). Translation affects it.
    pub inline fn TransformPoint(m: Self, p: Vec3) Vec3{
        const r = MulVec4(m, Vec4.Make(p.x, p.y, p.z, 1.0));
        return Vec3.Make(r.x, r.y, r.z);
    }

    // Transform a direction (w = 0). Translation does NOT affect it
    pub inline fn TransformVector(m: Self, v: Vec3) Vec3{
        const r = MulVec4(m, Vec4.Make(v.x, v.y, v.z, 0.0));
        return Vec3.Make(r.x, r.y, r.z);
    }

    // Create a pure translation matrix
    pub inline fn Translation(v: Vec3) Self {
        return Make(
            Vec4.Make(1.0, 0.0, 0.0, 0.0),
            Vec4.Make(0.0, 1.0, 0.0, 0.0),
            Vec4.Make(0.0, 0.0, 1.0, 0.0),
            Vec4.Make(v.x, v.y, v.z, 1.0),
        );

    }

    /// Translate in world space: t += (vx, vy, vz, 0)
    pub inline fn TranslateWorld(m: Self, v: Vec3) Self {
        return Make(
            m.i, m.j, m.k,
            Vec4.Make(m.t.x + v.x, m.t.y + v.y, m.t.z + v.z, m.t.w),
        );
    }

    /// Translate in local space: t += i*vx + j*vy + k*vz
    pub inline fn TranslateLocal(m: Self, v: Vec3) Self {
        return Make(
            m.i, m.j, m.k,
            Vec4.Make(
                m.t.x + m.i.x * v.x + m.j.x * v.y + m.k.x * v.z,
                m.t.y + m.i.y * v.x + m.j.y * v.y + m.k.y * v.z,
                m.t.z + m.i.z * v.x + m.j.z * v.y + m.k.z * v.z,
                m.t.w,
            ),
        );
    }
    
    // Scale Matrix
    pub inline fn Scale(v: Vec3) Self {
        return Make(
            Vec4.Make(v.x, 0.0, 0.0, 0.0),
            Vec4.Make(0.0, v.y, 0.0, 0.0),
            Vec4.Make(0.0, 0.0, v.z, 0.0),
            Vec4.Make(0.0, 0.0, 0.0, 1.0),
        );
    }

   pub fn Rotation(axis: Vec3, angle_rad: f32) Mat4{
        const len_sq = axis.x * axis.x + axis.y * axis.y + axis.z * axis.z;
        if (len_sq == 0.0) return Mat4.IDENTITY;

        // If it's already unit-ish, skip sqrt
        if (@abs(len_sq - 1.0) <= 0.0001) {
            return RotationUnit(axis, angle_rad);
        }

        const inv_len =  1.0 / @sqrt(len_sq);
        const unit = Vec3.Make(axis.x * inv_len, axis.y * inv_len, axis.z * inv_len);
        return RotationUnit(unit, angle_rad);

   }

   // Rotation around an arbitrary axis (expects any axis; normalizes if needed)
   pub inline fn RotationUnit(axis: Vec3, angle_rad: f32) Mat4{
        const c = @cos(angle_rad);
        const s = @sin(angle_rad);
        const t = 1.0 - c;

        const x = axis.x;
        const y = axis.y;
        const z = axis.z;

        // Precomput repeated terms (fewer muls)
        const tx = t * x;
        const ty = t * y;
        const tz = t * z;

        const xx = tx * x;
        const yy = ty * y;
        const zz = tz * z;

        const xy = tx * y;
        const xz = tx * z;
        const yz = ty * z;

        const sx = s * x;
        const sy = s * y;
        const sz = s * z;

        return Make(
            Vec4.Make(xx + c, xy + sz, xz - sy, 0.0),
            Vec4.Make(xy - sz, yy + c, yz + sx, 0.0),
            Vec4.Make(xz + sy, yz - sx, zz + c, 0.0),
            Vec4.Make(0.0, 0.0, 0.0, 1.0),
        );
   }
    /// Pre-multiply rotation (world/frame rotation): R * M
    pub inline fn RotateWorld(m: Self, axis: Vec3, angle_rad: f32) Self {
        return Mul(Rotation(axis, angle_rad), m);
    }

    /// Post-multiply rotation (local/object rotation): M * R
    pub inline fn RotateLocal(m: Self, axis: Vec3, angle_rad: f32) Self {
        return Mul(m, Rotation(axis, angle_rad));
    }

    /// Perspective projection (right-handed, depth 0..1), column-vector convention.
    pub fn Perspective(fovy_rad: f32, aspect: f32, near: f32, far: f32) Self {
        std.debug.assert(@abs(aspect) > 0.0001);
        const f = 1.0 / @tan(fovy_rad * 0.5);

        // RH, Z in [0,1] (Vulkan/D3D style), with column vectors
        return Make(
            Vec4.Make(f / aspect, 0.0, 0.0, 0.0),
            Vec4.Make(0.0, f, 0.0, 0.0),
            Vec4.Make(0.0, 0.0, far / (near - far), -1.0),
            Vec4.Make(0.0, 0.0, (far * near) / (near - far), 0.0),
        );
    }

};

pub fn Ortho(
    left: f32,
    right: f32,
    bottom: f32,
    top: f32,
) Mat4 {
    return Mat4.Make(
        Vec4.Make( 2.0 / (right - left), 0.0, 0.0, 0.0),
        Vec4.Make( 0.0, 2.0 / (top - bottom), 0.0, 0.0),
        Vec4.Make( 0.0, 0.0, 1.0, 0.0), // Vulkan Z ∈ [0,1]
        Vec4.Make(
            -(right + left) / (right - left),
            -(top + bottom) / (top - bottom),
            0.0,
            1.0,
        ),
    );
}
