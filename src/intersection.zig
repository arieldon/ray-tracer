const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const mat = @import("matrix.zig");
const pln = @import("plane.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

pub const Intersection = struct {
    t: f32,
    shape: shp.Shape,
};

pub fn intersection(t: f32, s: shp.Shape) Intersection {
    return Intersection{
        .t = t,
        .shape = s,
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
    shape: shp.Shape,
    point: tup.Point,
    over_point: tup.Point,
    eye: tup.Vector,
    normal: tup.Vector,
    reflect: tup.Vector,
    inside: bool,
};

pub fn prepareComputations(i: Intersection, r: ray.Ray) Computation {
    var comps: Computation = undefined;

    // Copy properties of intersection.
    comps.t = i.t;
    comps.shape = i.shape;

    // Precompute useful values.
    comps.point = ray.position(r, i.t);
    comps.eye = -r.direction;
    comps.normal = switch (i.shape.shape_type) {
        .sphere => sph.normal_at(i.shape, comps.point),
        .plane  => pln.normal_at(i.shape, comps.point),
    };

    if (tup.dot(comps.normal, comps.eye) < 0) {
        comps.inside = true;
        comps.normal = -comps.normal;
    } else {
        comps.inside = false;
    }

    // Slightly adjust point in direction of normal vector to move the point
    // above the surface of the shape, effectively preventing the grain from
    // self-shadowing.
    comps.over_point = comps.point + comps.normal * @splat(4, @as(f32, tup.epsilon));

    // Precompute reflection vector.
    comps.reflect = tup.reflect(r.direction, comps.normal);

    return comps;
}

test "an intersection encapsulates t and object" {
    const s = sph.sphere();
    const i = intersection(3.5, s.shape);
    try expectEqual(i.t, 3.5);
    try expectEqual(i.shape, s.shape);
}

test "aggregating intersections" {
    const s = sph.sphere();
    const intersection1 = intersection(1, s.shape);
    const intersection2 = intersection(2, s.shape);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ intersection1, intersection2 });
    try expectEqual(xs.items.len, 2);
    try expectEqual(xs.items[0].t, 1);
    try expectEqual(xs.items[1].t, 2);
}

test "the hit, when all intersections have positive t" {
    const s = sph.sphere();
    const int1 = intersection(1, s.shape);
    const int2 = intersection(2, s.shape);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(&xs);
    try expectEqual(int, int1);
}

test "the hit, when some intersections have negative t" {
    const s = sph.sphere();
    const int1 = intersection(-1, s.shape);
    const int2 = intersection(1, s.shape);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(&xs);
    try expectEqual(int, int2);
}

test "the hit, when all intersections have negative t" {
    const s = sph.sphere();
    const int1 = intersection(-2, s.shape);
    const int2 = intersection(-1, s.shape);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(&xs);
    try expectEqual(int, null);
}

test "the hit is always the lowest nonnegative intersection" {
    const s = sph.sphere();
    const int1 = intersection(5, s.shape);
    const int2 = intersection(7, s.shape);
    const int3 = intersection(-3, s.shape);
    const int4 = intersection(2, s.shape);
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2, int3, int4 });
    const int = hit(&xs);
    try expectEqual(int, int4);
}

test "precomputing the state of an intersection" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const s = sph.sphere();
    const i = intersection(4, s.shape);
    const comps = prepareComputations(i, r);
    try expectEqual(comps.t, i.t);
    try expectEqual(comps.shape, i.shape);
    try expectEqual(comps.point, tup.point(0, 0, -1));
    try expectEqual(comps.eye, tup.vector(0, 0, -1));
    try expectEqual(comps.normal, tup.vector(0, 0, -1));
}

test "the hit, when an intersection occurs on the outside" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const s = sph.sphere();
    const i = intersection(4, s.shape);
    const comps = prepareComputations(i, r);
    try expectEqual(comps.inside, false);
}

test "the hit, when an intersection occurs on the inside" {
    const r = ray.ray(tup.point(0, 0, 0), tup.vector(0, 0, 1));
    const s = sph.sphere();
    const i = intersection(1, s.shape);
    const comps = prepareComputations(i, r);
    try expectEqual(comps.point, tup.point(0, 0, 1));
    try expectEqual(comps.eye, tup.vector(0, 0, -1));
    try expectEqual(comps.inside, true);
    try expectEqual(comps.normal, tup.vector(0, 0, -1));
}

test "the hit should offset the point" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));

    var s = sph.sphere();
    s.shape.transform = mat.translation(0, 0, 1);

    const i = intersection(5, s.shape);
    const comps = prepareComputations(i, r);

    try expect(comps.over_point[2] < -tup.epsilon / 2.0);
    try expect(comps.point[2] > comps.over_point[2]);
}

test "precomputing the reflection vector" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    const p = pln.plane();
    const r = ray.Ray{
        .origin = tup.point(0, 1, -1),
        .direction = tup.vector(0, -b, b),
    };
    const i = Intersection{
        .t = b,
        .shape = p.shape,
    };

    const comps = prepareComputations(i, r);
    try expectEqual(comps.reflect, tup.vector(0, b, b));
}
