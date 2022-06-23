const std = @import("std");
const expectEqual = std.testing.expectEqual;
const tup = @import("tuple.zig");

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

pub fn position(r: Ray, t: f32) tup.Point {
    return r.origin + r.direction * @splat(4, t);
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
