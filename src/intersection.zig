const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const cnv = @import("canvas.zig");
const cub = @import("cube.zig");
const cyl = @import("cylinder.zig");
const mat = @import("matrix.zig");
const pln = @import("plane.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

pub const Intersection = struct {
    t: f64,

    // FIXME Is it necessary to pass shape if normal already computed? I think
    // so, it seems the material is necessary to find the refractive index.
    // Intsead of passing the entire material, pass only the refractive field.
    shape_attrs: shp.CommonShapeAttributes,

    // FIXME This shouldn't be set by default. Make it an optional field
    // instead.
    normal: tup.Vector = tup.vector(-1, -1, -1),
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
    t: f64,
    n1: f64,
    n2: f64,
    shape_attrs: shp.CommonShapeAttributes,
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
    comps.shape_attrs = i.shape_attrs;

    // Precompute useful values.
    comps.point = ray.position(r, i.t);
    comps.eye = -r.direction;

    // FIXME Is it necessary to copy the normal vector. I think it's fine for
    // now because it's only a 32-bit float.
    if (tup.dot(i.normal, comps.eye) < 0) {
        comps.inside = true;
        comps.normal = -i.normal;
    } else {
        comps.inside = false;
        comps.normal = i.normal;
    }

    // Slightly adjust point in direction of normal vector to move the point
    // above the surface of the shape, effectively preventing the grain from
    // self-shadowing.
    comps.over_point = comps.point + comps.normal * @splat(4, @as(f64, tup.epsilon));

    // Slighly adjust point below the surface of the shape to describe where
    // refracted rays originate.
    comps.under_point = comps.point - comps.normal * @splat(4, @as(f64, tup.epsilon));

    // Precompute reflection vector.
    comps.reflect = tup.reflect(r.direction, comps.normal);

    // Leave n1 and n2 undefined. Use prepareComputationsForRefraction() to
    // calculate these values.
    comps.n1 = undefined;
    comps.n2 = undefined;

    return comps;
}

pub fn prepareComputationsForRefraction(i: Intersection, r: ray.Ray, xs: []Intersection) Computation {
    // Calculate values of struct unrelated to refractive indices.
    var comps = prepareComputations(i, r);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const ShapeList = std.TailQueue(shp.CommonShapeAttributes);
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
            if (std.meta.eql(node.data, x.shape_attrs)) {
                _ = containers.remove(node);
                break;
            }
        } else {
            // FIXME Handle OutOfMemory error gracefully.
            const node = allocator.create(ShapeList.Node) catch unreachable;
            node.data = x.shape_attrs;
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

pub fn schlick(comps: Computation) f64 {
    // Schlick's approximation serves as an approximation for the Fresnel
    // equation, which determines the amounts of light reflected and refracted
    // at an intersection.
    var r0 = (comps.n1 - comps.n2) / (comps.n1 + comps.n2);
    r0 *= r0;

    var cos = tup.dot(comps.eye, comps.normal);
    if (comps.n1 > comps.n2) {
        const n = comps.n1 / comps.n2;
        const sin2_t = n * n * (1.0 - cos * cos);

        // Total internal reflection occurs in this case.
        if (sin2_t > 1.0) return 1.0;

        cos = @sqrt(1.0 - sin2_t);
    }

    return r0 + (1 - r0) * std.math.pow(f64, 1 - cos, 5);
}

test "an intersection encapsulates t and object" {
    const s = sph.Sphere{};
    const i = Intersection{ .t = 3.5, .shape_attrs = s.common_attrs };
    try expectEqual(i.t, 3.5);
    try expectEqual(i.shape_attrs, s.common_attrs);
}

test "aggregating intersections" {
    const s = sph.Sphere{};
    var intersection1 = Intersection{ .t = 1, .shape_attrs = s.common_attrs };
    var intersection2 = Intersection{ .t = 2, .shape_attrs = s.common_attrs };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ intersection1, intersection2 });
    try expectEqual(xs.items.len, 2);
    try expectEqual(xs.items[0].t, 1);
    try expectEqual(xs.items[1].t, 2);
}

test "the hit, when all intersections have positive t" {
    const s = sph.Sphere{};
    var int1 = Intersection{ .t = 1, .shape_attrs = s.common_attrs };
    var int2 = Intersection{ .t = 2, .shape_attrs = s.common_attrs };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(xs.items);
    try expectEqual(int, int1);
}

test "the hit, when some intersections have negative t" {
    const s = sph.Sphere{};
    var int1 = Intersection{ .t = -1, .shape_attrs = s.common_attrs };
    var int2 = Intersection{ .t = 1, .shape_attrs = s.common_attrs };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(xs.items);
    try expectEqual(int, int2);
}

test "the hit, when all intersections have negative t" {
    const s = sph.Sphere{};
    var int1 = Intersection{ .t = -2, .shape_attrs = s.common_attrs };
    var int2 = Intersection{ .t = -1, .shape_attrs = s.common_attrs };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2 });
    const int = hit(xs.items);
    try expectEqual(int, null);
}

test "the hit is always the lowest nonnegative intersection" {
    const s = sph.Sphere{};
    var int1 = Intersection{ .t = 5, .shape_attrs = s.common_attrs };
    var int2 = Intersection{ .t = 7, .shape_attrs = s.common_attrs };
    var int3 = Intersection{ .t = -3, .shape_attrs = s.common_attrs };
    var int4 = Intersection{ .t = 2, .shape_attrs = s.common_attrs };
    var xs = std.ArrayList(Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersections(&xs, &[_]Intersection{ int1, int2, int3, int4 });
    const int = hit(xs.items);
    try expectEqual(int, int4);
}

test "precomputing the state of an intersection" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const s = sph.Sphere{};
    const t = 4;
    const i = Intersection{
        .t = t,
        .shape_attrs = s.common_attrs,
        .normal = sph.normalAt(s, ray.position(r, t))
    };
    const comps = prepareComputations(i, r);
    try expectEqual(comps.t, i.t);
    try expectEqual(comps.shape_attrs, i.shape_attrs);
    try expectEqual(comps.point, tup.point(0, 0, -1));
    try expectEqual(comps.eye, tup.vector(0, 0, -1));
    try expectEqual(comps.normal, tup.vector(0, 0, -1));
}

test "the hit, when an intersection occurs on the outside" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));
    const s = sph.Sphere{};
    const t = 4;
    const i = Intersection{
        .t = t,
        .shape_attrs = s.common_attrs,
        .normal = sph.normalAt(s, ray.position(r, t)),
    };
    const comps = prepareComputations(i, r);
    try expectEqual(comps.inside, false);
}

test "the hit, when an intersection occurs on the inside" {
    const r = ray.ray(tup.point(0, 0, 0), tup.vector(0, 0, 1));
    const s = sph.Sphere{};
    const t = 1;
    const i = Intersection{
        .t = t,
        .shape_attrs = s.common_attrs,
        .normal = sph.normalAt(s, ray.position(r, t)),
    };
    const comps = prepareComputations(i, r);
    try expectEqual(comps.point, tup.point(0, 0, 1));
    try expectEqual(comps.eye, tup.vector(0, 0, -1));
    try expectEqual(comps.inside, true);
    try expectEqual(comps.normal, tup.vector(0, 0, -1));
}

test "the hit should offset the point" {
    const r = ray.ray(tup.point(0, 0, -5), tup.vector(0, 0, 1));

    const s = sph.Sphere{
        .common_attrs = .{
            .transform = mat.translation(0, 0, 1),
        },
    };

    const i = Intersection{ .t = 5, .shape_attrs = s.common_attrs };
    const comps = prepareComputations(i, r);

    try expect(comps.over_point[2] < -tup.epsilon / 2.0);
    try expect(comps.point[2] > comps.over_point[2]);
}

test "precomputing the reflection vector" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    const p = pln.Plane{};
    const r = ray.Ray{
        .origin = tup.point(0, 1, -1),
        .direction = tup.vector(0, -b, b),
    };
    const i = Intersection{
        .t = b,
        .shape_attrs = p.common_attrs,
        .normal = pln.normalAt(p, ray.position(r, b))
    };

    const comps = prepareComputations(i, r);
    try expectEqual(comps.reflect, tup.vector(0, b, b));
}

test "finding n1 and n2 at various intersections" {
    const a = sph.Sphere{
        .common_attrs = .{
            .material = .{
                .refractive_index = 1.5,
                .transparency = 1.0,
            },
            .transform = mat.scaling(2, 2, 2),
        },
    };
    const b = sph.Sphere{
        .common_attrs = .{
            .material = .{
                .refractive_index = 2.0,
                .transparency = 1.0,
            },
            .transform = mat.translation(0, 0, -0.25),
        },
    };
    const c = sph.Sphere{
        .common_attrs = .{
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
        .{ .t = 2.00, .shape_attrs = a.common_attrs },
        .{ .t = 2.75, .shape_attrs = b.common_attrs },
        .{ .t = 3.25, .shape_attrs = c.common_attrs },
        .{ .t = 4.75, .shape_attrs = b.common_attrs },
        .{ .t = 5.25, .shape_attrs = c.common_attrs },
        .{ .t = 6.00, .shape_attrs = a.common_attrs },
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
        .common_attrs = .{
            .material = .{
                .refractive_index = 1.5,
                .transparency = 1.0,
            },
            .transform = mat.translation(0, 0, 1),
        },
    };
    const i = Intersection{ .t = 5, .shape_attrs = sphere.common_attrs };

    const comps = prepareComputations(i, r);
    try expect(comps.under_point[2] > tup.epsilon / 2.0);
    try expect(comps.point[2] < comps.under_point[2]);
}

test "the Schlick approximation under total internal reflection" {
    const a = @sqrt(2.0);
    const b = a / 2.0;

    const sphere = sph.Sphere{
        .common_attrs = .{
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
        .{
            .t = -b,
            .shape_attrs = sphere.common_attrs,
            .normal = sph.normalAt(sphere, ray.position(r, -b)),
        },
        .{
            .t =  b,
            .shape_attrs = sphere.common_attrs,
            .normal = sph.normalAt(sphere, ray.position(r, b)),
        },
    };
    const comps = prepareComputationsForRefraction(xs[1], r, xs);

    const reflectance = schlick(comps);
    try expectEqual(reflectance, 1.0);
}

test "the Schlick approximation with a perpendicular viewing angle" {
    const sphere = sph.Sphere{
        .common_attrs = .{
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
        .{ .t = -1, .shape_attrs = sphere.common_attrs },
        .{ .t =  1, .shape_attrs = sphere.common_attrs },
    };
    const comps = prepareComputationsForRefraction(xs[1], r, xs);

    const reflectance = schlick(comps);
    try expectApproxEqAbs(reflectance, 0.04, tup.epsilon);
}

test "the Schlick approximation with small angle and n2 > n1" {
    const sphere = sph.Sphere{
        .common_attrs = .{
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
    const t = 1.8589;
    const xs = &[_]Intersection{
        .{
            .t = t,
            .shape_attrs = sphere.common_attrs,
            .normal = sph.normalAt(sphere, ray.position(r, t))
        },
    };
    const comps = prepareComputationsForRefraction(xs[0], r, xs);

    const reflectance = schlick(comps);
    try expectApproxEqAbs(reflectance, 0.48873, tup.epsilon);
}
