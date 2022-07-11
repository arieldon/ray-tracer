const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
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

pub inline fn intersections(xs: *std.ArrayList(Intersection), new: []Intersection) !void {
    try xs.appendSlice(new);
}

pub fn hit(xs: []Intersection) ?Intersection {
    const static = struct {
        fn cmp(context: void, a: Intersection, b: Intersection) bool {
            _ = context;
            return a.t < b.t;
        }
    };
    std.sort.sort(Intersection, xs, {}, comptime static.cmp);

    for (xs) |x| if (x.t >= 0) return x;
    return null;
}

pub const Computation = struct {
    t: f32,
    n1: f32,
    n2: f32,
    shape: shp.Shape,
    point: tup.Point,
    over_point: tup.Point,
    under_point: tup.Point,
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

    // Slighly adjust point below the surface of the shape to describe where
    // refracted rays originate.
    comps.under_point = comps.point - comps.normal * @splat(4, @as(f32, tup.epsilon));

    // Precompute reflection vector.
    comps.reflect = tup.reflect(r.direction, comps.normal);

    // Set default value for n1 and n2. Use prepareComputationsForRefraction()
    // to calculate these values.
    comps.n1 = 1.0;
    comps.n2 = 1.0;

    return comps;
}

pub fn prepareComputationsForRefraction(i: Intersection, r: ray.Ray, xs: []Intersection) Computation {
    // Calculate values of struct unrelated to refractive indices.
    var comps = prepareComputations(i, r);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ShapeList = std.TailQueue(shp.Shape);
    var containers = ShapeList{};

    for (xs) |x| {
        if (std.meta.eql(x, i)) {
            if (containers.len == 0) {
                comps.n1 = 1.0;
            } else {
                comps.n1 = containers.last.?.data.material.refractive_index;
            }
        }

        // If the intersection occurs with a shape already hit once by the ray,
        // then this subsequent intersection must be the ray exiting shape:
        // It's no longer necessary to track this shape. If the intersection
        // occurs with a shape not yet stored in the list, then append it to
        // calculate the subsequent intersection.
        var it = containers.first;
        while (it) |node| : (it = node.next) {
            if (std.meta.eql(node.data, x.shape)) {
                _ = containers.remove(node);
                break;
            }
        } else {
            // FIXME Handle OutOfMemory error gracefully.
            const node = allocator.create(ShapeList.Node) catch unreachable;
            node.data = x.shape;
            containers.append(node);
        }

        if (std.meta.eql(x, i)) {
            if (containers.len == 0) {
                comps.n2 = 1.0;
            } else {
                comps.n2 = containers.last.?.data.material.refractive_index;
            }
            break;
        }
    }

    return comps;
}

pub fn schlick(comps: Computation) f32 {
    var cos = tup.dot(comps.eye, comps.normal);

    if (comps.n1 > comps.n2) {
        const n = comps.n1 / comps.n2;
        const sin2_t = (n * n) * (1.0 - (cos * cos));

        if (sin2_t > 1.0) return 1.0;

        const cos_t = @sqrt(1.0 - sin2_t);
        cos = cos_t;
    }

    const r0 = (comps.n1 - comps.n2) / (comps.n1 + comps.n2);
    const r0_squared = r0 * r0;
    return r0_squared + (1 - r0_squared) * std.math.pow(f32, 1 - cos, 5);
}

test "an intersection encapsulates t and object" {
    const s = sph.sphere();
    const i = Intersection{ .t = 3.5, .shape = s.shape };
    try expectEqual(i.t, 3.5);
    try expectEqual(i.shape, s.shape);
}

test "aggregating intersections" {
    const s = sph.sphere();
    const intersection1 = Intersection{ .t = 1, .shape = s.shape };
    const intersection2 = Intersection{ .t = 2, .shape = s.shape };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ intersection1, intersection2 });
    try expectEqual(xs.items.len, 2);
    try expectEqual(xs.items[0].t, 1);
    try expectEqual(xs.items[1].t, 2);
}

test "the hit, when all intersections have positive t" {
    const s = sph.sphere();
    const int1 = Intersection{ .t = 1, .shape = s.shape };
    const int2 = Intersection{ .t = 2, .shape = s.shape };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(xs.items);
    try expectEqual(int, int1);
}

test "the hit, when some intersections have negative t" {
    const s = sph.sphere();
    const int1 = Intersection{ .t = -1, .shape = s.shape };
    const int2 = Intersection{ .t = 1, .shape = s.shape };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(xs.items);
    try expectEqual(int, int2);
}

test "the hit, when all intersections have negative t" {
    const s = sph.sphere();
    const int1 = Intersection{ .t = -2, .shape = s.shape };
    const int2 = Intersection{ .t = -1, .shape = s.shape };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(xs.items);
    try expectEqual(int, null);
}

test "the hit is always the lowest nonnegative intersection" {
    const s = sph.sphere();
    const int1 = Intersection{ .t = 5, .shape = s.shape };
    const int2 = Intersection{ .t = 7, .shape = s.shape };
    const int3 = Intersection{ .t = -3, .shape = s.shape };
    const int4 = Intersection{ .t = 2, .shape = s.shape };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2, int3, int4 });
    const int = hit(xs.items);
    try expectEqual(int, int4);
}

test "precomputing the state of an intersection" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const s = sph.sphere();
    const i = Intersection{ .t = 4, .shape = s.shape };
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
    const i = Intersection{ .t = 4, .shape = s.shape };
    const comps = prepareComputations(i, r);
    try expectEqual(comps.inside, false);
}

test "the hit, when an intersection occurs on the inside" {
    const r = ray.ray(tup.point(0, 0, 0), tup.vector(0, 0, 1));
    const s = sph.sphere();
    const i = Intersection{ .t = 1, .shape = s.shape };
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

    const i = Intersection{ .t = 5, .shape = s.shape };
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

test "finding n1 and n2 at various intersections" {
    const a = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .material = .{
                .refractive_index = 1.5,
                .transparency = 1.0,
            },
            .transform = mat.scaling(2, 2, 2),
        },
    };
    const b = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .material = .{
                .refractive_index = 2.0,
                .transparency = 1.0,
            },
            .transform = mat.translation(0, 0, -0.25),
        },
    };
    const c = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .material = .{
                .refractive_index = 2.5,
                .transparency = 1.0,
            },
            .transform = mat.translation(0, 0, 0.25),
        },
    };

    const r = ray.Ray{
        .origin = tup.point(0, 0, -4),
        .direction = tup.vector(0, 0, 1),
    };

    const xs = &[_]Intersection{
        .{ .t = 2.00, .shape = a.shape },
        .{ .t = 2.75, .shape = b.shape },
        .{ .t = 3.25, .shape = c.shape },
        .{ .t = 4.75, .shape = b.shape },
        .{ .t = 5.25, .shape = c.shape },
        .{ .t = 6.00, .shape = a.shape },
    };

    inline for (.{
        .{ .n1 = 1.0, .n2 = 1.5 },
        .{ .n1 = 1.5, .n2 = 2.0 },
        .{ .n1 = 2.0, .n2 = 2.5 },
        .{ .n1 = 2.5, .n2 = 2.5 },
        .{ .n1 = 2.5, .n2 = 1.5 },
        .{ .n1 = 1.5, .n2 = 1.0 },
    }) |x, index| {
        const comps = prepareComputationsForRefraction(xs[index], r, xs);
        try expectEqual(comps.n1, x.n1);
        try expectEqual(comps.n2, x.n2);
    }
}

test "the under point is offset below the surface" {
    const r = ray.Ray{
        .origin = tup.point(0, 0, -5),
        .direction = tup.vector(0, 0, 1),
    };
    const sphere = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .material = .{
                .refractive_index = 1.5,
                .transparency = 1.0,
            },
            .transform = mat.translation(0, 0, 1),
        },
    };
    const i = Intersection{ .t = 5, .shape = sphere.shape };

    const comps = prepareComputations(i, r);
    try expect(comps.under_point[2] > tup.epsilon / 2.0);
    try expect(comps.point[2] < comps.under_point[2]);
}

test "the Schlick approximation under total internal reflection" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    const sphere = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .material = .{
                .refractive_index = 1.5,
                .transparency = 1.0,
            },
            .transform = mat.scaling(2, 2, 2),
        },
    };
    const r = ray.Ray{
        .origin = tup.point(0, 0, b),
        .direction = tup.vector(0, 1, 0),
    };
    const xs = &[_]Intersection{
        .{ .t = -b, .shape = sphere.shape },
        .{ .t =  b, .shape = sphere.shape },
    };
    const comps = prepareComputationsForRefraction(xs[1], r, xs);

    const reflectance = schlick(comps);
    try expectEqual(reflectance, 1.0);
}

test "the Schlick approximation with a perpendicular viewing angle" {
    const sphere = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .material = .{
                .refractive_index = 1.5,
                .transparency = 1.0,
            },
            .transform = mat.scaling(2, 2, 2),
        },
    };
    const r = ray.Ray{
        .origin = tup.point(0, 0, 0),
        .direction = tup.vector(0, 1, 0),
    };
    const xs = &[_]Intersection{
        .{ .t = -1, .shape = sphere.shape },
        .{ .t =  1, .shape = sphere.shape },
    };
    const comps = prepareComputationsForRefraction(xs[1], r, xs);

    const reflectance = schlick(comps);
    try expectApproxEqAbs(reflectance, 0.04, tup.epsilon);
}

test "the Schlick approximation with small angle and n2 > n1" {
    const sphere = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .material = .{
                .refractive_index = 1.5,
                .transparency = 1.0,
            },
            .transform = mat.scaling(2, 2, 2),
        },
    };
    const r = ray.Ray{
        .origin = tup.point(0, 0.99, -2),
        .direction = tup.vector(0, 0, 1),
    };
    const xs = &[_]Intersection{ .{ .t = 1.8589, .shape = sphere.shape } };
    const comps = prepareComputationsForRefraction(xs[0], r, xs);

    const reflectance = schlick(comps);
    try expectApproxEqAbs(reflectance, 0.48873, tup.epsilon);
}
