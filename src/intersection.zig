const std = @import("std");
const expectEqual = std.testing.expectEqual;
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
