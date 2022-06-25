const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;

pub const Tuple = @Vector(4, f32);
pub const Vector = Tuple;
pub const Point = Tuple;

pub fn tuple(x: f32, y: f32, z: f32, w: f32) Tuple {
    return .{ x, y, z, w };
}

pub fn point(x: f32, y: f32, z: f32) Point {
    return .{ x, y, z, 1 };
}

pub fn vector(x: f32, y: f32, z: f32) Vector {
    return .{ x, y, z, 0 };
}

pub fn isPoint(t: Tuple) bool {
    return t[3] == 1;
}

pub fn isVector(t: Tuple) bool {
    return t[3] == 0;
}

pub fn equal(a: Tuple, b: Tuple, epsilon: f32) bool {
    return @reduce(.And, @fabs(a - b) <= @splat(4, epsilon));
}

pub fn dot(u: Vector, v: Vector) f32 {
    return u[0] * v[0] + u[1] * v[1] + u[2] * v[2] + u[3] * v[3];
}

pub fn cross(u: Vector, v: Vector) Vector {
    return .{
        u[1] * v[2] - u[2] * v[1],
        u[2] * v[0] - u[0] * v[2],
        u[0] * v[1] - u[1] * v[0],
    };
}

pub fn magnitude(v: Vector) f32 {
    return @sqrt(dot(v, v));
}

pub fn normalize(v: Vector) Vector {
    return v / @splat(4, @as(f32, magnitude(v)));
}

pub fn reflect(in: Vector, normal: Vector) Vector {
    return in - normal * @splat(4, dot(in, normal)) * @splat(4, @as(f32, 2.0));
}

test "a tuple with w=1.0 is a point" {
    const a = tuple(4.3, -4.2, 3.1, 1.0);

    try expect(a[0] == 4.3);
    try expect(a[1] == -4.2);
    try expect(a[2] == 3.1);
    try expect(a[3] == 1.0);

    try expect(isPoint(a) == true);
    try expect(isVector(a) == false);
}

test "a tuple with w=0 is a vector" {
    const a = tuple(4.3, -4.2, 3.1, 0.0);

    try expect(a[0] == 4.3);
    try expect(a[1] == -4.2);
    try expect(a[2] == 3.1);
    try expect(a[3] == 0.0);

    try expect(isPoint(a) == false);
    try expect(isVector(a) == true);
}

test "point() creates tuples with w=1" {
    const p = point(4, -4, 3);
    try expectEqual(p, tuple(4, -4, 3, 1));
}

test "vector() creates tuples with w=0" {
    const v = vector(4, -4, 3);
    try expectEqual(v, tuple(4, -4, 3, 0));
}

test "adding two tuples" {
    const a1 = tuple(3, -2, 5, 1);
    const a2 = tuple(-2, 3, 1, 0);
    try expectEqual(a1 + a2, tuple(1, 1, 6, 1));
}

test "subtracting two points" {
    const p1 = point(3, 2, 1);
    const p2 = point(5, 6, 7);
    try expectEqual(p1 - p2, vector(-2, -4, -6));
}

test "subtracting a vector from a point" {
    const p = point(3, 2, 1);
    const v = vector(5, 6, 7);
    try expectEqual(p - v, point(-2, -4, -6));
}

test "subtracting two vectors" {
    const v1 = vector(3, 2, 1);
    const v2 = vector(5, 6, 7);
    try expectEqual(v1 - v2, vector(-2, -4, -6));
}

test "subtracting a vector from the zero vector" {
    const zero = vector(0, 0, 0);
    const v = vector(1, -2, 3);
    try expectEqual(zero - v, vector(-1, 2, -3));
}

test "negating a tuple" {
    const a = tuple(1, -2, 3, -4);
    try expectEqual(-a, tuple(-1, 2, -3, 4));
}

test "multiplying a tuple by a scalar" {
    const a = tuple(1, -2, 3, -4);
    try expectEqual(a * @splat(4, @as(f32, 3.5)), tuple(3.5, -7, 10.5, -14));
}

test "multiplying a tuple by a fraction" {
    const a = tuple(1, -2, 3, -4);
    try expectEqual(a * @splat(4, @as(f32, 0.5)), tuple(0.5, -1, 1.5, -2));
}

test "dividing a tuple by a scalar" {
    const a = tuple(1, -2, 3, -4);
    try expectEqual(a / @splat(4, @as(f32, 2)), tuple(0.5, -1, 1.5, -2));
}

test "the dot product of two tuples" {
    const a = vector(1, 2, 3);
    const b = vector(2, 3, 4);
    try expectEqual(dot(a, b), 20);
}

test "computing the magnitude of vector(1, 0, 0)" {
    const v = vector(1, 0, 0);
    try expectEqual(magnitude(v), 1);
}

test "computing the magnitude of vector(0, 1, 0)" {
    const v = vector(0, 1, 0);
    try expectEqual(magnitude(v), 1);
}

test "computing the magnitude of vector(0, 0, 1)" {
    const v = vector(0, 0, 1);
    try expectEqual(magnitude(v), 1);
}

test "computing the magnitude of vector(1, 2, 3)" {
    const v = vector(1, 2, 3);
    try expectEqual(magnitude(v), @sqrt(14.0));
}

test "computing the magnitude of vector(-1, -2, -3)" {
    const v = vector(-1, -2, -3);
    try expectEqual(magnitude(v), @sqrt(14.0));
}

test "normalizing vector(4, 0, 0) gives (1, 0, 0)" {
    const v = vector(4, 0, 0);
    try expectEqual(normalize(v), vector(1, 0, 0));
}

test "normalizing vector(1, 2, 3)" {
    const v = normalize(vector(1, 2, 3));
    const a = @sqrt(14.0);
    const e = 0.00001;

    try expectApproxEqAbs(@floatCast(f32, 1 / a), v[0], e);
    try expectApproxEqAbs(@floatCast(f32, 2 / a), v[1], e);
    try expectApproxEqAbs(@floatCast(f32, 3 / a), v[2], e);
}

test "the magnitude of a normalized vector" {
    const v = vector(1, 2, 3);
    const n = normalize(v);
    const e = 0.00001;
    try expectApproxEqAbs(magnitude(n), 1, e);
}

test "the cross product of two vectors" {
    const a = vector(1, 2, 3);
    const b = vector(2, 3, 4);

    try expectEqual(cross(a, b), vector(-1, 2, -1));
    try expectEqual(cross(b, a), vector(1, -2, 1));
}

test "reflecting a vector approaching at 45 degrees" {
    const v = vector(1, -1, 0);
    const n = vector(0, 1, 0);
    const r = reflect(v, n);
    try expectEqual(r, vector(1, 1, 0));
}

test "reflecting a vector off a slanted surface" {
    const v = vector(0, -1, 0);
    const a = @sqrt(2.0) / 2.0;
    const n = vector(a, a, 0);
    const r = reflect(v, n);
    try expect(equal(r, vector(1, 0, 0), 0.00001));
}
