const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const tup = @import("tuple.zig");
const Tuple = tup.Tuple;
const tuple = tup.tuple;
const point = tup.point;
const vector = tup.vector;

pub const Matrix = Matrix4x4;
pub const Matrix4x4 = [4]@Vector(4, f32);
pub const Matrix3x3 = [3]@Vector(3, f32);
pub const Matrix2x2 = [2]@Vector(2, f32);

const identity = Matrix{
    .{ 1, 0, 0, 0 },
    .{ 0, 1, 0, 0 },
    .{ 0, 0, 1, 0 },
    .{ 0, 0, 0, 1 },
};

pub fn equal(a: Matrix, b: Matrix, epsilon: f32) bool {
    var row: u8 = 0;
    while (row < 4) : (row += 1) {
        if (@reduce(.And, @fabs(a[row] - b[row]) > @splat(4, epsilon))) {
            return false;
        }
    }
    return true;
}

pub fn mul(a: anytype, b: anytype) typeMulOp(@TypeOf(a), @TypeOf(b)) {
    const t0 = @TypeOf(a);
    const t1 = @TypeOf(b);
    if (t0 == Matrix and t1 == Matrix) {
        return mulMatrix(a, b);
    } else if (t0 == Matrix and t1 == Tuple) {
        return mulTuple(a, b);
    } else {
        @compileError("Unable to multiply types " ++ @typeName(t0) ++ " and " ++ @typeName(t1) ++ ".");
    }
}

pub fn mulMatrix(a: Matrix, b: Matrix) Matrix {
    var c: Matrix = undefined;

    // TODO Vectorize.
    var row: u8 = 0;
    while (row < 4) : (row += 1) {
        var col: u8 = 0;
        while (col < 4) : (col += 1) {
            c[row][col] =
                a[row][0] * b[0][col] +
                a[row][1] * b[1][col] +
                a[row][2] * b[2][col] +
                a[row][3] * b[3][col];
        }
    }

    return c;
}

pub fn mulTuple(a: Matrix, b: Tuple) Tuple {
    return .{ tup.dot(a[0], b), tup.dot(a[1], b), tup.dot(a[2], b), tup.dot(a[3], b) };
}

fn typeMulOp(comptime t0: type, t1: type) type {
    if (t0 == Matrix and t1 == Matrix) {
        return Matrix;
    } else if (t0 == Matrix and t1 == Tuple) {
        return Tuple;
    }
}

pub fn transpose(m: Matrix) Matrix {
    var n: Matrix = undefined;

    // TODO Vectorize.
    var row: u8 = 0;
    while (row < 4) : (row += 1) {
        var col: u8 = 0;
        while (col < 4) : (col += 1) {
            n[row][col] = m[col][row];
        }
    }

    return n;
}

pub fn determinant(m: anytype) f32 {
    comptime {
        const t = @TypeOf(m);
        if (t != Matrix2x2 and t != Matrix3x3 and t != Matrix4x4) {
            @compileError("Unable to calculate determinant of type " ++ @typeName(t) ++ ".");
        }
    }

    var det: f32 = 0;

    if (m.len == 2) {
        det = m[0][0] * m[1][1] - m[0][1] * m[1][0];
    } else {
        var col: u8 = 0;
        while (col < m.len) : (col += 1) det += m[0][col] * cofactor(m, 0, col);
    }

    return det;
}

fn submatrix(m: anytype, row: u32, col: u32) typeSubmatrix(@TypeOf(m)) {
    var n: typeSubmatrix(@TypeOf(m)) = undefined;

    var y: u32 = 0;
    var j: u32 = 0;
    while (j < m.len) : (j += 1) {
        if (j == row) continue;
        var x: u32 = 0;
        var i: u32 = 0;
        while (i < m.len) : (i += 1) {
            if (i == col) continue;
            n[y][x] = m[j][i];
            x += 1;
        }
        y += 1;
    }

    return n;
}

fn typeSubmatrix(comptime t: type) type {
    return switch (t) {
        Matrix4x4 => Matrix3x3,
        Matrix3x3 => Matrix2x2,
        else => @compileError("Unable to determine type of submatrix for type " ++ @typeName(t) ++ "."),
    };
}

fn minor(m: anytype, row: u32, col: u32) f32 {
    return determinant(submatrix(m, row, col));
}

fn cofactor(m: anytype, row: u32, col: u32) f32 {
    if ((row + col) % 2 == 0) {
        return minor(m, row, col);
    } else {
        return -minor(m, row, col);
    }
}

inline fn isInvertible(m: Matrix) bool {
    return determinant(m) != 0;
}

pub fn inverse(m: Matrix) Matrix {
    std.debug.assert(isInvertible(m));

    var n: Matrix = undefined;

    var row: u8 = 0;
    while (row < 4) : (row += 1) {
        var col: u8 = 0;
        while (col < 4) : (col += 1) {
            const c = cofactor(m, row, col);
            n[col][row] = c / determinant(m);
        }
    }

    return n;
}

pub fn translation(x: f32, y: f32, z: f32) Matrix {
    return .{
        .{ 1, 0, 0, x },
        .{ 0, 1, 0, y },
        .{ 0, 0, 1, z },
        .{ 0, 0, 0, 1 },
    };
}

pub fn scaling(x: f32, y: f32, z: f32) Matrix {
    return .{
        .{ x, 0, 0, 0 },
        .{ 0, y, 0, 0 },
        .{ 0, 0, z, 0 },
        .{ 0, 0, 0, 1 },
    };
}

pub fn rotationX(r: f32) Matrix {
    return .{
        .{ 1, 0, 0, 0 },
        .{ 0, @cos(r), -@sin(r), 0 },
        .{ 0, @sin(r), @cos(r), 0 },
        .{ 0, 0, 0, 1 },
    };
}

pub fn rotationY(r: f32) Matrix {
    return .{
        .{
            @cos(r),
            0,
            @sin(r),
            0,
        },
        .{ 0, 1, 0, 0 },
        .{ -@sin(r), 0, @cos(r), 0 },
        .{ 0, 0, 0, 1 },
    };
}

pub fn rotationZ(r: f32) Matrix {
    return .{
        .{ @cos(r), -@sin(r), 0, 0 },
        .{ @sin(r), @cos(r), 0, 0 },
        .{ 0, 0, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
}

pub fn shearing(xy: f32, xz: f32, yx: f32, yz: f32, zx: f32, zy: f32) Matrix {
    return .{
        .{ 1, xy, xz, 0 },
        .{ yx, 1, yz, 0 },
        .{ zx, zy, 1, 0 },
        .{ 0, 0, 0, 1 },
    };
}

test "constructing and inspecting a 4x4 matrix" {
    const m = Matrix{
        .{ 1, 2, 3, 4 },
        .{ 5.5, 6.5, 7.5, 8.5 },
        .{ 9, 10, 11, 12 },
        .{ 13.5, 14.5, 15.5, 16.5 },
    };
    try expectEqual(m[0][0], 1);
    try expectEqual(m[0][3], 4);
    try expectEqual(m[1][0], 5.5);
    try expectEqual(m[1][2], 7.5);
    try expectEqual(m[2][2], 11);
    try expectEqual(m[3][0], 13.5);
    try expectEqual(m[3][2], 15.5);
}

test "matrix equality with identical matrices" {
    const a = Matrix{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 8, 7, 6 },
        .{ 5, 4, 3, 2 },
    };
    const b = Matrix{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 8, 7, 6 },
        .{ 5, 4, 3, 2 },
    };
    try expect(equal(a, b, 0.00001));
}

test "matrix equality with different matrices" {
    const a = Matrix{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 8, 7, 6 },
        .{ 5, 4, 3, 2 },
    };
    const b = Matrix{
        .{ 2, 3, 4, 5 },
        .{ 6, 7, 8, 9 },
        .{ 8, 7, 6, 5 },
        .{ 4, 3, 2, 1 },
    };
    try expect(!equal(a, b, 0.00001));
}

test "multiplying two matrices" {
    const a = Matrix{
        .{ 1, 2, 3, 4 },
        .{ 5, 6, 7, 8 },
        .{ 9, 8, 7, 6 },
        .{ 5, 4, 3, 2 },
    };
    const b = Matrix{
        .{ -2, 1, 2, 3 },
        .{ 3, 2, 1, -1 },
        .{ 4, 3, 6, 5 },
        .{ 1, 2, 7, 8 },
    };
    const c = Matrix{
        .{ 20, 22, 50, 48 },
        .{ 44, 54, 114, 108 },
        .{ 40, 58, 110, 102 },
        .{ 16, 26, 46, 42 },
    };
    try expectEqual(mulMatrix(a, b), c);
}

test "a matrix multiplied by a tuple" {
    const a = Matrix{
        .{ 1, 2, 3, 4 },
        .{ 2, 4, 4, 2 },
        .{ 8, 6, 4, 1 },
        .{ 0, 0, 0, 1 },
    };
    const b = tuple(1, 2, 3, 1);
    try expectEqual(mulTuple(a, b), tuple(18, 24, 33, 1));
}

test "multiplying a matrix by the identity matrix" {
    const a = Matrix{
        .{ 0, 1, 2, 4 },
        .{ 1, 2, 4, 8 },
        .{ 2, 4, 8, 16 },
        .{ 4, 8, 16, 32 },
    };
    try expectEqual(mulMatrix(a, identity), a);
}

test "transposing a matrix" {
    const a = Matrix{
        .{ 0, 9, 3, 0 },
        .{ 9, 8, 0, 8 },
        .{ 1, 8, 5, 3 },
        .{ 0, 0, 5, 8 },
    };
    const b = Matrix{
        .{ 0, 9, 1, 0 },
        .{ 9, 8, 8, 0 },
        .{ 3, 0, 5, 5 },
        .{ 0, 8, 3, 8 },
    };
    try expectEqual(transpose(a), b);
}

test "transposing the identity matrix" {
    const a = transpose(identity);
    try expectEqual(a, identity);
}

test "calculating the determinant of a 2x2 matrix" {
    const a = Matrix2x2{
        .{ 1, 5 },
        .{ -3, 2 },
    };
    try expectEqual(determinant(a), 17);
}

test "a submatrix of a 3x3 matrix is a 2x2 matrix" {
    const a = Matrix3x3{
        .{ 1, 5, 0 },
        .{ -3, 2, 7 },
        .{ 0, 6, -3 },
    };
    const b = Matrix2x2{
        .{ -3, 2 },
        .{ 0, 6 },
    };
    try expectEqual(submatrix(a, 0, 2), b);
}

test "a submatrix of a 4x4 matrix is a 3x3 matrix" {
    const a = Matrix4x4{
        .{ -6, 1, 1, 6 },
        .{ -8, 5, 8, 6 },
        .{ -1, 0, 8, 2 },
        .{ -7, 1, -1, 1 },
    };
    const b = Matrix3x3{
        .{ -6, 1, 6 },
        .{ -8, 8, 6 },
        .{ -7, -1, 1 },
    };
    try expectEqual(submatrix(a, 2, 1), b);
}

test "calculating a minor of a 3x3 matrix" {
    const a = Matrix3x3{
        .{ 3, 5, 0 },
        .{ 2, -1, -7 },
        .{ 6, -1, 5 },
    };
    const b = submatrix(a, 1, 0);
    try expectEqual(determinant(b), 25);
    try expectEqual(minor(a, 1, 0), 25);
}

test "calculating a cofactor of a 3x3 matrix" {
    const a = Matrix3x3{
        .{ 3, 5, 0 },
        .{ 2, -1, -7 },
        .{ 6, -1, 5 },
    };
    try expectEqual(minor(a, 0, 0), -12);
    try expectEqual(cofactor(a, 0, 0), -12);
    try expectEqual(minor(a, 1, 0), 25);
    try expectEqual(cofactor(a, 1, 0), -25);
}

test "calculating the determinant of a 3x3 matrix" {
    const a = Matrix3x3{
        .{ 1, 2, 6 },
        .{ -5, 8, -4 },
        .{ 2, 6, 4 },
    };
    try expectEqual(cofactor(a, 0, 0), 56);
    try expectEqual(cofactor(a, 0, 1), 12);
    try expectEqual(cofactor(a, 0, 2), -46);
    try expectEqual(determinant(a), -196);
}

test "calculating the determinant of a 4x4 matrix" {
    const a = Matrix4x4{
        .{ -2, -8, 3, 5 },
        .{ -3, 1, 7, 3 },
        .{ 1, 2, -9, 6 },
        .{ -6, 7, 7, -9 },
    };
    try expectEqual(cofactor(a, 0, 0), 690);
    try expectEqual(cofactor(a, 0, 1), 447);
    try expectEqual(cofactor(a, 0, 2), 210);
    try expectEqual(cofactor(a, 0, 3), 51);
    try expectEqual(determinant(a), -4071);
}

test "testing an invertible matrix for invertibility" {
    const a = Matrix4x4{
        .{ 6, 4, 4, 4 },
        .{ 5, 5, 7, 6 },
        .{ 4, -9, 3, -7 },
        .{ 9, 1, 7, -6 },
    };
    try expectEqual(determinant(a), -2120);
    try expect(isInvertible(a));
}

test "testing a noninvertible matrix for invertibility" {
    const a = Matrix4x4{
        .{ -4, 2, -2, -3 },
        .{ 9, 6, 2, 6 },
        .{ 0, -5, 1, -5 },
        .{ 0, 0, 0, 0 },
    };
    try expectEqual(determinant(a), 0);
    try expect(!isInvertible(a));
}

test "calculating the inverse of a matrix" {
    const a = Matrix4x4{
        .{ -5, 2, 6, -8 },
        .{ 1, -5, 1, 8 },
        .{ 7, 7, -6, -7 },
        .{ 1, -3, 7, 4 },
    };
    const b = inverse(a);
    const c = Matrix4x4{
        .{ 0.21805, 0.45113, 0.24060, -0.04511 },
        .{ -0.80827, -1.45677, -0.44361, 0.52068 },
        .{ -0.07895, -0.22368, -0.05263, 0.19737 },
        .{ -0.52256, -0.81391, -0.30075, 0.30639 },
    };

    try expectEqual(determinant(a), 532);
    try expectEqual(cofactor(a, 2, 3), -160);
    try expectEqual(b[3][2], -160.0 / 532.0);
    try expectEqual(cofactor(a, 3, 2), 105);
    try expectEqual(b[2][3], 105.0 / 532.0);
    try expect(equal(b, c, 0.00001));
}

test "calculating the inverse of another matrix" {
    const a = Matrix4x4{
        .{ 8, -5, 9, 2 },
        .{ 7, 5, 6, 1 },
        .{ -6, 0, 9, 6 },
        .{ -3, 0, -9, -4 },
    };
    const b = Matrix4x4{
        .{ -0.15385, -0.15385, -0.28205, -0.53846 },
        .{ -0.07692, 0.12308, 0.02564, 0.03077 },
        .{ 0.35897, 0.35897, 0.43590, 0.92308 },
        .{ -0.69231, -0.69231, -0.76923, -1.92308 },
    };
    try expect(equal(inverse(a), b, 0.00001));
}

test "calculating the inverse of a third matrix" {
    const a = Matrix4x4{
        .{ 9, 3, 0, 9 },
        .{ -5, -2, -6, -3 },
        .{ -4, 9, 6, 4 },
        .{ -7, 6, 6, 2 },
    };
    const b = Matrix4x4{
        .{ -0.04074, -0.07778, 0.14444, -0.22222 },
        .{ -0.07778, 0.03333, 0.36667, -0.33333 },
        .{ -0.02901, -0.14630, -0.10926, 0.12963 },
        .{ 0.17778, 0.06667, -0.26667, 0.33333 },
    };
    try expect(equal(inverse(a), b, 0.00001));
}

test "multiplying a product by its inverse" {
    const a = Matrix4x4{
        .{ 3, -9, 7, 3 },
        .{ 3, -8, 2, -9 },
        .{ -4, 4, 4, 1 },
        .{ -6, 5, -1, 1 },
    };
    const b = Matrix4x4{
        .{ 8, 2, 2, 2 },
        .{ 3, -1, 7, 0 },
        .{ 7, 0, 5, 4 },
        .{ 6, -2, 0, 5 },
    };
    const c = mul(a, b);
    try expect(equal(mul(c, inverse(b)), a, 0.00001));
}

test "multiplying by a translation matrix" {
    const transform = translation(5, -3, 2);
    const p = point(-3, 4, 5);
    try expectEqual(mul(transform, p), point(2, 1, 7));
}

test "multiplying by the inverse of a translation matrix" {
    const transform = translation(5, -3, 2);
    const inv = inverse(transform);
    const p = point(-3, 4, 5);
    try expectEqual(mul(inv, p), point(-8, 7, 3));
}

test "translation does not affect vectors" {
    const transform = translation(5, -3, 2);
    const v = vector(-3, 4, 5);
    try expectEqual(mul(transform, v), v);
}

test "a scaling matrix applied to a point" {
    const transform = scaling(2, 3, 4);
    const p = point(-4, 6, 8);
    try expectEqual(mul(transform, p), point(-8, 18, 32));
}

test "a scaling matrix applied to a vector" {
    const transform = scaling(2, 3, 4);
    const v = vector(-4, 6, 8);
    try expectEqual(mul(transform, v), vector(-8, 18, 32));
}

test "multiplying by the inverse of a scaling matrix" {
    const transform = scaling(2, 3, 4);
    const inv = inverse(transform);
    const v = vector(-4, 6, 8);
    try expectEqual(mul(inv, v), vector(-2, 2, 2));
}

test "reflection is scaling by a negative value" {
    const transform = scaling(-1, 1, 1);
    const p = point(2, 3, 4);
    try expectEqual(mul(transform, p), point(-2, 3, 4));
}

test "rotating a point around the x axis" {
    const p = point(0, 1, 0);
    const half_quarter = rotationX(std.math.pi / 4.0);
    const full_quarter = rotationX(std.math.pi / 2.0);
    try expect(tup.equal(mul(half_quarter, p), point(0, @sqrt(2.0) / 2.0, @sqrt(2.0) / 2.0), 0.0001));
    try expect(tup.equal(mul(full_quarter, p), point(0, 0, 1), 0.00001));
}

test "the inverse of an x-rotation rotates in the opposite direction" {
    const p = point(0, 1, 0);
    const half_quarter = rotationX(std.math.pi / 4.0);
    const inv = inverse(half_quarter);
    try expect(tup.equal(mul(inv, p), point(0, @sqrt(2.0) / 2.0, -@sqrt(2.0) / 2.0), 0.00001));
}

test "rotating a point around the y axis" {
    const p = point(0, 0, 1);
    const half_quarter = rotationY(std.math.pi / 4.0);
    const full_quarter = rotationY(std.math.pi / 2.0);
    try expect(tup.equal(mul(half_quarter, p), point(@sqrt(2.0) / 2.0, 0, @sqrt(2.0) / 2.0), 0.00001));
    try expect(tup.equal(mul(full_quarter, p), point(1, 0, 0), 0.00001));
}

test "rotating a point around the z axis" {
    const p = point(0, 1, 0);
    const half_quarter = rotationZ(std.math.pi / 4.0);
    const full_quarter = rotationZ(std.math.pi / 2.0);
    try expect(tup.equal(mul(half_quarter, p), point(-@sqrt(2.0) / 2.0, @sqrt(2.0) / 2.0, 0), 0.00001));
    try expect(tup.equal(mul(full_quarter, p), point(-1, 0, 0), 0.00001));
}

test "a shearing transformation moves x in proportion to y" {
    const transform = shearing(1, 0, 0, 0, 0, 0);
    const p = point(2, 3, 4);
    try expectEqual(mul(transform, p), point(5, 3, 4));
}

test "a shearing transformation moves x in proportion to z" {
    const transform = shearing(0, 1, 0, 0, 0, 0);
    const p = point(2, 3, 4);
    try expectEqual(mul(transform, p), point(6, 3, 4));
}

test "a shearing transformation moves y in proportion to x" {
    const transform = shearing(0, 0, 1, 0, 0, 0);
    const p = point(2, 3, 4);
    try expectEqual(mul(transform, p), point(2, 5, 4));
}

test "a shearing transformation moves y in proportion to z" {
    const transform = shearing(0, 0, 0, 1, 0, 0);
    const p = point(2, 3, 4);
    try expectEqual(mul(transform, p), point(2, 7, 4));
}

test "a shearing transformation moves z in proportion to x" {
    const transform = shearing(0, 0, 0, 0, 1, 0);
    const p = point(2, 3, 4);
    try expectEqual(mul(transform, p), point(2, 3, 6));
}

test "a shearing transformation moves z in proportion to y" {
    const transform = shearing(0, 0, 0, 0, 0, 1);
    const p = point(2, 3, 4);
    try expectEqual(mul(transform, p), point(2, 3, 7));
}

test "individual transformations are applied in sequence" {
    const p = point(1, 0, 1);
    const a = rotationX(std.math.pi / 2.0);
    const b = scaling(5, 5, 5);
    const c = translation(10, 5, 7);

    const p2 = mul(a, p);
    try expect(tup.equal(p2, point(1, -1, 0), 0.00001));

    const p3 = mul(b, p2);
    try expect(tup.equal(p3, point(5, -5, 0), 0.00001));

    const p4 = mul(c, p3);
    try expect(tup.equal(p4, point(15, 0, 7), 0.00001));
}

test "chained transformations must be applied in reverse order" {
    const p = point(1, 0, 1);
    const a = rotationX(std.math.pi / 2.0);
    const b = scaling(5, 5, 5);
    const c = translation(10, 5, 7);
    const t = mul(c, mul(b, a));
    try expect(tup.equal(mul(t, p), point(15, 0, 7), 0.00001));
}
