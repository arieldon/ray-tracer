const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const tup = @import("tuple.zig");
const Tuple = tup.Tuple;
const tuple = tup.tuple;

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
