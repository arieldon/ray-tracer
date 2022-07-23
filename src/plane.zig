const std = @import("std");
const expectEqual = std.testing.expectEqual;
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

// A plane is an infinite 2D flat surface. It defaults to the xz-axis, but it
// may be transformed to appear in any orientation.
pub const Plane = struct {
    shape: shp.Shape,
};

pub fn plane() Plane {
    return .{ .shape = .{ .shape_type = .plane } };
}

pub fn intersect(ts: *std.ArrayList(int.Intersection), p: Plane, r: ray.Ray) !void {
    // Transform the ray by the inverse of the transformation of the plane to
    // effectively apply the transformation of the plane without losing the
    // convenience of the "unit" plane.
    const r_prime = ray.transform(r, mat.inverse(p.shape.transform));

    // A ray parallel to a plane will not intersect it at any point. A ray with
    // a y-component of zero is parallel to the plane since the plane sits on
    // the xz-axis, and a plane in the xz axis doesn't have a rate of change in
    // the y-axis.
    if (@fabs(r_prime.direction[1]) < tup.epsilon) return;

    // Compute the intersection of the transformed ray with the plane.
    const t = -r_prime.origin[1] / r_prime.direction[1];
    try ts.append(int.Intersection{
        .t = t,
        .shape = p.shape,
        .normal = normalAt(p.shape, ray.position(r, t)),
    });
}

pub fn normalAt(shape: shp.Shape, world_point: tup.Point) tup.Vector {
    // The point in the world isn't necessary since the normal vector of a
    // plane remains constant at all points.
    _ = world_point;

    // The surface normal vector of a plane remains constant at all points
    // because a plane doesn't curve.
    var n = mat.mul(mat.transpose(mat.inverse(shape.transform)), tup.vector(0, 1, 0));

    // HACK: Reset w to 0 to accommodate translation transformations. It's more
    // correct to multiply by the inverse transpose of the submatrix in the
    // previous calculation, but this achieves the same result with fewer
    // computations.
    n[3] = 0;

    return tup.normalize(n);
}

test "the normal of a plane is constant everywhere" {
    const p = plane();
    const n1 = normalAt(p.shape, tup.point(0, 0, 0));
    const n2 = normalAt(p.shape, tup.point(10, 0, -10));
    const n3 = normalAt(p.shape, tup.point(-5, 0, 150));
    try expectEqual(n1, tup.vector(0, 1, 0));
    try expectEqual(n2, tup.vector(0, 1, 0));
    try expectEqual(n3, tup.vector(0, 1, 0));
}

test "intersect with a ray parallel to the plane" {
    const p = plane();
    const r = ray.ray(tup.point(0, 10, 0), tup.vector(0, 0, 1));

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, p, r);
    try expectEqual(xs.items.len, 0);
}

test "intersect with a coplanar ray" {
    const p = plane();
    const r = ray.ray(tup.point(0, 10, 0), tup.vector(0, 0, 1));

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, p, r);
    try expectEqual(xs.items.len, 0);
}

test "a ray intersecting a plane from above" {
    const p = plane();
    const r = ray.ray(tup.point(0, 1, 0), tup.vector(0, -1, 0));

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, p, r);
    try expectEqual(xs.items.len, 1);
    try expectEqual(xs.items[0].t, 1);
    try expectEqual(xs.items[0].shape, p.shape);
}

test "a ray intersecting a plane from below" {
    const p = plane();
    const r = ray.ray(tup.point(0, -1, 0), tup.vector(0, 1, 0));

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, p, r);
    try expectEqual(xs.items.len, 1);
    try expectEqual(xs.items[0].t, 1);
    try expectEqual(xs.items[0].shape, p.shape);
}
