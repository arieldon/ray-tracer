const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expect = std.testing.expect;
const mat = @import("matrix.zig");
const tup = @import("tuple.zig");

pub fn viewTransform(from: tup.Point, to: tup.Point, up: tup.Vector) mat.Matrix {
    const forward = tup.normalize(to - from);
    const left = tup.cross(forward, tup.normalize(up));
    const true_up = tup.cross(left, forward);
    const orientation = mat.Matrix{
        .{left[0], left[1], left[2], 0},
        .{true_up[0], true_up[1], true_up[2], 0},
        .{-forward[0], -forward[1], -forward[2], 0},
        .{0, 0, 0, 1},
    };
    return mat.mul(orientation, mat.translation(-from[0], -from[1], -from[2]));
}

test "the transformation matrix for the default orientation" {
    const from = tup.point(0, 0, 0);
    const to = tup.point(0, 0, 1);
    const up = tup.vector(0, 1, 0);
    const t = viewTransform(from, to, up);
    try expectEqual(t, mat.scaling(-1, 1, -1));
}

test "the view transformation moves the world" {
    const from = tup.point(0, 0, 8);
    const to = tup.point(0, 0, 0);
    const up = tup.vector(0, 1, 0);
    const t = viewTransform(from, to, up);
    try expectEqual(t, mat.translation(0, 0, -8));
}

test "an arbitrary view transformation" {
    const from = tup.point(1, 3, 2);
    const to = tup.point(4, -2, 8);
    const up = tup.vector(1, 1, 0);
    const t = viewTransform(from, to, up);
    const a = mat.Matrix{
        .{-0.50709, 0.50709, 0.67612, -2.36643},
        .{0.76772, 0.60609, 0.12122, -2.82843},
        .{-0.35857, 0.59761, -0.71714, 0.00000},
        .{0.00000, 0.00000, 0.00000, 1.00000},
    };
    try expect(mat.equal(t, a, 0.00001));
}
