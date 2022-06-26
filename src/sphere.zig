const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const tup = @import("tuple.zig");
const mtl = @import("material.zig");

pub const Sphere = struct {
    id: u8,
    material: mtl.Material = mtl.material(),
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

    // Calculate the vector from the center of the sphere to the origin of the
    // ray, where the sphere is a unit sphere and thus centered about the
    // origin with a radius of one.
    const sphere_to_ray = r_prime.origin - tup.point(0, 0, 0);

    // Calculate the variables in the discriminant (b^2 - 4ac) from the
    // quadratic formula algebraically. In this case, the equation in quadratic
    // form derives from the equation of a sphere centered about the origin:
    // P^2 - R^2 = 0, where P is some point (x, y, z) on the coordinate plane
    // and R is the radius of the unit sphere. Replace P with the equation for
    // a point along a ray: P(t) = O + tD, where O and D represent the origin
    // and direction of the ray, respectively. Expand the expression and
    // rearrange the variables to match the following table.
    //      a <- D^2
    //      b <- 2 * D . O
    //      c <- O^2 - R^2
    const a = tup.dot(r_prime.direction, r_prime.direction);
    const b = 2 * tup.dot(r_prime.direction, sphere_to_ray);
    const c = tup.dot(sphere_to_ray, sphere_to_ray) - 1;

    // Use the discriminant to determine the number of intersections and their
    // t values if they exist.
    const discriminant = b * b - 4 * a * c;
    if (discriminant >= 0) {
        // When the ray intersects a sphere at two unique points, both t values
        // will be unique. When the ray is tangent to the sphere and it
        // intersects at one point, both t values will be the same. In this
        // latter case, the discriminant is zero.
        var t1 = int.intersection((-b - @sqrt(discriminant)) / (2 * a), s);
        var t2 = int.intersection((-b + @sqrt(discriminant)) / (2 * a), s);
        try ts.appendSlice(&[_]int.Intersection{ t1, t2 });
    }
}

pub fn normal_at(s: Sphere, world_point: tup.Point) tup.Vector {
    const inverse = mat.inverse(s.transform);

    // Convert the point from world space to object space. Because the sphere
    // may be transformed -- skewed, translated, scaled, or what not -- in
    // world space, it's necessary to calculate the surface normal vector
    // relative to the sphere rather than the world.
    const object_point = mat.mul(inverse, world_point);

    // With the point in object space, it's easy to calculate the surface
    // normal vector: the center of the sphere from the point in question. With
    // the base assumption that all spheres are unit spheres in this ray
    // tracer, the center of the sphere is the origin of the coordinate plane.
    const object_normal = object_point - tup.point(0, 0, 0);

    // Convert the surface normal vector from object space to world space.
    // Multiply by the transpose of the inverse to keep the surface normal
    // vector perpendicular to the surface of the sphere.
    var world_normal = mat.mul(mat.transpose(inverse), object_normal);

    // HACK: Reset w to 0 to accommodate translation transformations. It's more
    // proper to multiply by the inverse transpose of the submatrix in the
    // previous calculation, but this achieves the same result, faster.
    world_normal[3] = 0;

    return tup.normalize(world_normal);
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

test "the normal on a sphere at a point on the x axis" {
    const s = sphere();
    const n = normal_at(s, tup.point(1, 0, 0));
    try expectEqual(n, tup.vector(1, 0, 0));
}

test "the normal on a sphere at a point on the y axis" {
    const s = sphere();
    const n = normal_at(s, tup.point(0, 1, 0));
    try expectEqual(n, tup.vector(0, 1, 0));
}

test "the normal on a sphere at a point on the z axis" {
    const s = sphere();
    const n = normal_at(s, tup.point(0, 0, 1));
    try expectEqual(n, tup.vector(0, 0, 1));
}

test "the normal on a sphere at a nonaxial point" {
    const s = sphere();
    const a = @sqrt(3.0) / 3.0;
    const n = normal_at(s, tup.point(a, a, a));
    try expect(tup.equal(n, tup.vector(a, a, a), 0.00001));
}

test "the normal is a normalized vector" {
    const s = sphere();
    const a = @sqrt(3.0) / 3.0;
    const n = normal_at(s, tup.point(a, a, a));
    try expect(tup.equal(n, tup.normalize(n), 0.00001));
}

test "computing the normal on a translated sphere" {
    var s = sphere();
    s.transform = mat.translation(0, 1, 0);
    const n = normal_at(s, tup.point(0, 1.70711, -0.70711));
    try expect(tup.equal(n, tup.vector(0, 0.70711, -0.70711), 0.00001));
}

test "computing the normal on a transformed sphere" {
    var s = sphere();
    s.transform = mat.mul(mat.scaling(1, 0.5, 1), mat.rotationZ(std.math.pi / 5.0));
    const a = @sqrt(2.0) / 2.0;
    const n = normal_at(s, tup.point(0, a, -a));
    try expect(tup.equal(n, tup.vector(0, 0.97014, -0.24254), 0.00001));
}

test "a sphere has a default material" {
    const s = sphere();
    const m = mtl.material();
    try expectEqual(m, s.material);
}

test "a sphere may be assigned a material" {
    var s = sphere();
    var m = mtl.material();
    m.ambient = 1;
    s.material = m;
    try expectEqual(m, s.material);
}
