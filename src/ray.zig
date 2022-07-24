const std = @import("std");
const expectEqual = std.testing.expectEqual;
const tup = @import("tuple.zig");
const mat = @import("matrix.zig");

pub const Ray = struct {
    origin: tup.Point,
    direction: tup.Vector,
};

pub fn ray(origin: tup.Point, direction: tup.Vector) Ray {
    return Ray{
        .origin = origin,
        .direction = direction,
    };
}

pub fn position(r: Ray, t: f64) tup.Point {
    return r.origin + r.direction * @splat(4, t);
}

pub fn transform(r: Ray, m: mat.Matrix) Ray {
    return Ray{
        .origin = mat.mul(m, r.origin),
        .direction = mat.mul(m, r.direction),
    };
}

test "creating and querying a ray" {
    const origin = tup.point(1, 2, 3);
    const direction = tup.vector(4, 5, 6);

    const r = ray(origin, direction);
    try expectEqual(r.origin, origin);
    try expectEqual(r.direction, direction);
}

test "computing a point from a distance" {
    const r = ray(tup.point(2, 3, 4), tup.vector(1, 0, 0));
    try expectEqual(position(r, 0), tup.point(2, 3, 4));
    try expectEqual(position(r, 1), tup.point(3, 3, 4));
    try expectEqual(position(r, -1), tup.point(1, 3, 4));
    try expectEqual(position(r, 2.5), tup.point(4.5, 3, 4));
}

test "translating a ray" {
    const r = ray(tup.point(1, 2, 3), tup.vector(0, 1, 0));
    const m = mat.translation(3, 4, 5);

    const r2 = transform(r, m);
    try expectEqual(r2.origin, tup.point(4, 6, 8));
    try expectEqual(r2.direction, tup.vector(0, 1, 0));
}

test "scaling a ray" {
    const r = ray(tup.point(1, 2, 3), tup.vector(0, 1, 0));
    const m = mat.scaling(2, 3, 4);

    const r2 = transform(r, m);
    try expectEqual(r2.origin, tup.point(2, 6, 12));
    try expectEqual(r2.direction, tup.vector(0, 3, 0));
}
