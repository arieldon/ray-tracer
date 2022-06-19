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

pub fn equal(a: Matrix, b: Matrix) bool {
    for (a) |_, i| if (@reduce(.And, a[i] != b[i])) return false;
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
    try expect(equal(a, b));
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
    try expect(!equal(a, b));
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
