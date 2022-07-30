const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const int = @import("intersection.zig");
const ray = @import("ray.zig");
const tup = @import("tuple.zig");

pub const Triangle = struct {
    p0: tup.Point,
    p1: tup.Point,
    p2: tup.Point,
    e0: tup.Vector,
    e1: tup.Vector,
    normal: tup.Vector,

    pub fn init(p0: tup.Point, p1: tup.Point, p2: tup.Point) Triangle {
        const e0 = p1 - p0;
        const e1 = p2 - p0;
        return Triangle{
            .p0 = p0,
            .p1 = p1,
            .p2 = p2,
            .e0 = e0,
            .e1 = e1,
            .normal = tup.normalize(tup.cross(e1, e0)),
        };
    }
};

pub fn intersect(ts: *std.ArrayList(int.Intersection), triangle: Triangle, r: ray.Ray) !void {
    const dir_cross_e1 = tup.cross(r.direction, triangle.e1);
    const det = tup.dot(triangle.e0, dir_cross_e1);
    if (@fabs(det) < tup.epsilon) return;

    const f = 1.0 / det;
    const p0_to_origin = r.origin - triangle.p0;
    const u = f * tup.dot(p0_to_origin, dir_cross_e1);
    if (u < 0 or u > 1) return;

    const origin_cross_e0 = tup.cross(p0_to_origin, triangle.e0);
    const v = f * tup.dot(r.direction, origin_cross_e0);
    if (v < 0 or (u + v) > 1) return;

    const t = f * tup.dot(triangle.e1, origin_cross_e0);
    try ts.append(int.Intersection{
        .t = t,
        .shape_attrs = undefined,
        .normal = normalAt(triangle, ray.position(r, t)),
    });
}

pub inline fn normalAt(t: Triangle, world_point: tup.Point) tup.Vector {
    _ = world_point;
    return t.normal;
}

test "constructing a triangle" {
    const p0 = tup.point(0, 1, 0);
    const p1 = tup.point(-1, 0, 0);
    const p2 = tup.point(1, 0, 0);
    const t = Triangle.init(p0, p1, p2);

    try expectEqual(t.p0, p0);
    try expectEqual(t.p1, p1);
    try expectEqual(t.p2, p2);
    try expectEqual(t.e0, tup.vector(-1, -1, 0));
    try expectEqual(t.e1, tup.vector(1, -1, 0));
    try expect(tup.equal(t.normal, tup.vector(0, 0, -1)));
}

test "finding the normal on a triangle" {
    const t = Triangle.init(tup.point(0, 1, 0), tup.point(-1, 0, 0), tup.point(1, 0, 0));
    const n1 = normalAt(t, tup.point(0, 0.5, 0));
    const n2 = normalAt(t, tup.point(-0.5, 0.75, 0));
    const n3 = normalAt(t, tup.point(0.5, 0.25, 0));

    try expectEqual(n1, t.normal);
    try expectEqual(n2, t.normal);
    try expectEqual(n3, t.normal);
}

test "intersecting a ray parallel to the triangle" {
    const t = Triangle.init(tup.point(0, 1, 0), tup.point(-1, 0, 0), tup.point(1, 0, 0));
    const r = ray.Ray{
        .origin = tup.point(0, -1, -2),
        .direction = tup.vector(0, 1, 0),
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, t, r);
    try expectEqual(xs.items.len, 0);
}

test "a ray misses the p0-p2 edge" {
    const t = Triangle.init(tup.point(0, 1, 0), tup.point(-1, 0, 0), tup.point(1, 0, 0));
    const r = ray.Ray{
        .origin = tup.point(1, 1, -2),
        .direction = tup.vector(0, 0, 1),
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, t, r);
    try expectEqual(xs.items.len, 0);
}

test "a ray misses the p0-p1 edge" {
    const t = Triangle.init(tup.point(0, 1, 0), tup.point(-1, 0, 0), tup.point(1, 0, 0));
    const r = ray.Ray{
        .origin = tup.point(-1, 1, -2),
        .direction = tup.vector(0, 0, 1),
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, t, r);
    try expectEqual(xs.items.len, 0);
}

test "a ray misses the p1-p2 edge" {
    const t = Triangle.init(tup.point(0, 1, 0), tup.point(-1, 0, 0), tup.point(1, 0, 0));
    const r = ray.Ray{
        .origin = tup.point(0, -1, -2),
        .direction = tup.vector(0, 0, 1),
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, t, r);
    try expectEqual(xs.items.len, 0);
}

test "a ray strikes a triangle" {
    const t = Triangle.init(tup.point(0, 1, 0), tup.point(-1, 0, 0), tup.point(1, 0, 0));
    const r = ray.Ray{
        .origin = tup.point(0, 0.5, -2),
        .direction = tup.vector(0, 0, 1),
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, t, r);
    try expectEqual(xs.items.len, 1);
    try expectEqual(xs.items[0].t, 2);
}
