const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

pub const Intersection = struct {
    t: f32,
    object: sph.Sphere,
};

pub fn intersection(t: f32, s: sph.Sphere) Intersection {
    return Intersection{
        .t = t,
        .object = s,
    };
}

pub inline fn intersections(xs: *std.ArrayList(Intersection), new: []Intersection) !void {
    try xs.appendSlice(new);
}

pub fn hit(xs: *std.ArrayList(Intersection)) ?Intersection {
    const static = struct {
        fn cmp(context: void, a: Intersection, b: Intersection) bool {
            _ = context;
            return a.t < b.t;
        }
    };
    std.sort.sort(Intersection, xs.items, {}, comptime static.cmp);

    for (xs.items) |x| {
        if (x.t >= 0) {
            return x;
        }
    }
    return null;
}

pub const Computation = struct {
    t: f32,
    object: sph.Sphere,
    point: tup.Point,
    over_point: tup.Point,
    eye: tup.Vector,
    normal: tup.Vector,
    inside: bool,
};

pub fn prepareComputations(i: Intersection, r: ray.Ray) Computation {
    var comps: Computation = undefined;

    // Copy properties of intersection.
    comps.t = i.t;
    comps.object = i.object;

    // Precompute useful values.
    comps.point = ray.position(r, i.t);
    comps.eye = -r.direction;
    comps.normal = sph.normal_at(i.object, comps.point);

    if (tup.dot(comps.normal, comps.eye) < 0) {
        comps.inside = true;
        comps.normal = -comps.normal;
    } else {
        comps.inside = false;
    }

    // Slightly adjust point in direction of normal vector to move the point
    // above the surface of the shape, effectively preventing the grain from
    // self-shadowing.
    comps.over_point = comps.point + comps.normal * @splat(4, cnv.color_epsilon);

    return comps;
}

test "an intersection encapsulates t and object" {
    const s = sph.sphere();
    const i = intersection(3.5, s);
    try expectEqual(i.t, 3.5);
    try expectEqual(i.object, s);
}

test "aggregating intersections" {
    const s = sph.sphere();
    const intersection1 = intersection(1, s);
    const intersection2 = intersection(2, s);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ intersection1, intersection2 });
    try expectEqual(xs.items.len, 2);
    try expectEqual(xs.items[0].t, 1);
    try expectEqual(xs.items[1].t, 2);
}

test "the hit, when all intersections have positive t" {
    const s = sph.sphere();
    const int1 = intersection(1, s);
    const int2 = intersection(2, s);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(&xs);
    try expectEqual(int, int1);
}

test "the hit, when some intersections have negative t" {
    const s = sph.sphere();
    const int1 = intersection(-1, s);
    const int2 = intersection(1, s);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(&xs);
    try expectEqual(int, int2);
}

test "the hit, when all intersections have negative t" {
    const s = sph.sphere();
    const int1 = intersection(-2, s);
    const int2 = intersection(-1, s);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(&xs);
    try expectEqual(int, null);
}

test "the hit is always the lowest nonnegative intersection" {
    const s = sph.sphere();
    const int1 = intersection(5, s);
    const int2 = intersection(7, s);
    const int3 = intersection(-3, s);
    const int4 = intersection(2, s);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2, int3, int4 });
    const int = hit(&xs);
    try expectEqual(int, int4);
}

test "precomputing the state of an intersection" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const shape = sph.sphere();
    const i = intersection(4, shape);
    const comps = prepareComputations(i, r);
    try expectEqual(comps.t, i.t);
    try expectEqual(comps.object, i.object);
    try expectEqual(comps.point, tup.point(0, 0, -1));
    try expectEqual(comps.eye, tup.vector(0, 0, -1));
    try expectEqual(comps.normal, tup.vector(0, 0, -1));
}

test "the hit, when an intersection occurs on the outside" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const shape = sph.sphere();
    const i = intersection(4, shape);
    const comps = prepareComputations(i, r);
    try expectEqual(comps.inside, false);
}

test "the hit, when an intersection occurs on the inside" {
    const r = ray.ray(tup.point(0, 0, 0), tup.vector(0, 0, 1));
    const shape = sph.sphere();
    const i = intersection(1, shape);
    const comps = prepareComputations(i, r);
    try expectEqual(comps.point, tup.point(0, 0, 1));
    try expectEqual(comps.eye, tup.vector(0, 0, -1));
    try expectEqual(comps.inside, true);
    try expectEqual(comps.normal, tup.vector(0, 0, -1));
}

test "the hit should offset the point" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));

    var shape = sph.sphere();
    shape.transform = mat.translation(0, 0, 1);

    const i = intersection(5, shape);
    const comps = prepareComputations(i, r);

    try expect(comps.over_point[2] < -cnv.color_epsilon / 2.0);
    try expect(comps.point[2] > comps.over_point[2]);
}
