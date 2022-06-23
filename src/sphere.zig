const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const tup = @import("tuple.zig");

pub const Sphere = struct {
    id: u8,
    transform: mat.Matrix = mat.identity,
};

pub fn sphere() Sphere {
    const static = struct {
        var id: u8 = 0;
    };

    const value = static.id;
    static.id += 1;

    return Sphere{
        .id = value,
    };
}

pub fn intersect(ts: *std.ArrayList(int.Intersection), s: Sphere, r: ray.Ray) !void {
    // Transform ray instead of sphere because fundamentally it's the distance
    // and orientation between the two that matters. This way, the sphere
    // technically remains a unit sphere, which preserves ease of use, but
    // transformations may still be applied to it to alter its appearance in
    // the scene.
    const r_prime = ray.transform(r, mat.inverse(s.transform));

    // Calculate the vector from the center of the sphere at the origin of the
    // world to the origin of the ray.
    const sphere_to_ray = r_prime.origin - tup.point(0, 0, 0);

    // TODO Document the rationale behind this formula.
    const a = tup.dot(r_prime.direction, r_prime.direction);
    const b = 2 * tup.dot(r_prime.direction, sphere_to_ray);
    const c = tup.dot(sphere_to_ray, sphere_to_ray) - 1;

    const discriminant = b * b - 4 * a * c;
    if (discriminant >= 0) {
        var t1 = int.intersection((-b - @sqrt(discriminant)) / (2 * a), s);
        var t2 = int.intersection((-b + @sqrt(discriminant)) / (2 * a), s);
        try ts.appendSlice(&[_]int.Intersection{ t1, t2 });
    }
}

test "a ray intersects a sphere at two points" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const s = sphere();
    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, s, r);
    try expectEqual(xs.items.len, 2);
    try expectApproxEqAbs(xs.items[0].t, 4.0, 0.00001);
    try expectApproxEqAbs(xs.items[1].t, 6.0, 0.00001);
}

test "a ray intersects a sphere at a tangent" {
    const r = ray.ray(tup.point(0, 1, -5), tup.vector(0, 0, 1));
    const s = sphere();
    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, s, r);
    try expectEqual(xs.items.len, 2);
    try expectApproxEqAbs(xs.items[0].t, 5.0, 0.00001);
    try expectApproxEqAbs(xs.items[1].t, 5.0, 0.00001);
}

test "a ray misses a sphere" {
    const r = ray.ray(tup.point(0, 2, -5), tup.vector(0, 0, 1));
    const s = sphere();
    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, s, r);
    try expectEqual(xs.items.len, 0);
}

test "a ray originates inside a sphere" {
    const r = ray.ray(tup.point(0, 0, 0), tup.vector(0, 0, 1));
    const s = sphere();
    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, s, r);
    try expectEqual(xs.items.len, 2);
    try expectEqual(xs.items[0].t, -1.0);
    try expectEqual(xs.items[1].t, 1.0);
}

test "a sphere is behind a ray" {
    const r = ray.ray(tup.point(0, 0, 5), tup.vector(0, 0, 1));
    const s = sphere();
    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, s, r);
    try expectEqual(xs.items.len, 2);
    try expectApproxEqAbs(xs.items[0].t, -6.0, 0.00001);
    try expectApproxEqAbs(xs.items[1].t, -4.0, 0.00001);
}

test "intersect sets the object on the intersection" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const s = sphere();
    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, s, r);
    try expectEqual(xs.items.len, 2);
    try expectEqual(xs.items[0].object, s);
    try expectEqual(xs.items[1].object, s);
}

test "a sphere's default transformation" {
    const s = sphere();
    try expectEqual(s.transform, mat.identity);
}

test "a changing a sphere's transformation" {
    var s = sphere();
    const t = mat.translation(2, 3, 4);
    s.transform = t;
    try expectEqual(s.transform, t);
}

test "intersecting a scaled sphere with a ray" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    var s = sphere();
    s.transform = mat.scaling(2, 2, 2);

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, s, r);
    try expectEqual(xs.items.len, 2);
    try expectEqual(xs.items[0].t, 3);
    try expectEqual(xs.items[1].t, 7);
}

test "intersecting a translated sphere with a ray" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    var s = sphere();
    s.transform = mat.translation(5, 0, 0);

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, s, r);
    try expectEqual(xs.items.len, 0);
}
