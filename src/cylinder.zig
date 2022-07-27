const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

pub const Cylinder = struct {
    common_attrs: shp.CommonShapeAttributes = .{},
    minimum: f64 = -std.math.inf_f64,
    maximum: f64 = std.math.inf_f64,
    closed: bool = false,
};

pub fn intersect(ts: *std.ArrayList(int.Intersection), cyl: Cylinder, r: ray.Ray) !void {
    const r_prime = ray.transform(r, mat.inverse(cyl.common_attrs.transform));

    // Because the ray is parallel to the y-axis, it will not intersect the
    // walls of the cylinder at any point. It may however intersect its caps.
    const a = r_prime.direction[0] * r_prime.direction[0] + r_prime.direction[2] * r_prime.direction[2];
    if (std.math.approxEqAbs(f64, a, 0, tup.epsilon)) {
        try intersectCaps(ts, cyl, r, r_prime);
        return;
    }

    const b = 2 * r_prime.origin[0] * r_prime.direction[0] +
              2 * r_prime.origin[2] * r_prime.direction[2];
    const c = r_prime.origin[0] * r_prime.origin[0] + r_prime.origin[2] * r_prime.origin[2] - 1;

    const discriminant = b * b - 4 * a * c;
    if (discriminant < 0) {
        try intersectCaps(ts, cyl, r, r_prime);
        return;
    }

    var t0 = (-b - @sqrt(discriminant)) / (2 * a);
    var t1 = (-b + @sqrt(discriminant)) / (2 * a);
    if (t0 > t1) std.mem.swap(f64, &t0, &t1);

    const y0 = @mulAdd(f64, t0, r_prime.direction[1], r_prime.origin[1]);
    if (cyl.minimum < y0 and y0 < cyl.maximum) {
        try ts.append(int.Intersection{
            .t = t0,
            .shape_attrs = cyl.common_attrs,
            .normal = normalAt(cyl, ray.position(r, t0)),
        });
    }

    const y1 = @mulAdd(f64, t1, r_prime.direction[1], r_prime.origin[1]);
    if (cyl.minimum < y1 and y1 < cyl.maximum) {
        try ts.append(int.Intersection{
            .t = t1,
            .shape_attrs = cyl.common_attrs,
            .normal = normalAt(cyl, ray.position(r, t1)),
        });
    }

    try intersectCaps(ts, cyl, r, r_prime);
}

fn intersectCaps(
    ts: *std.ArrayList(int.Intersection),
    cyl: Cylinder,
    r: ray.Ray,
    r_prime: ray.Ray,
) !void {
    // Caps only exist on a closed cylinder. They're also only relevant if the
    // ray may intersect them at some point, and the ray cannot intersect them
    // if [+].
    if (!cyl.closed or std.math.approxEqAbs(f64, r_prime.direction[1], 0, tup.epsilon)) return;

    // Check for intersection between ray and lower cap by intersecting the ray
    // with the plane that functions as this cap.
    const t_lower = (cyl.minimum - r_prime.origin[1]) / r_prime.direction[1];
    if (checkCap(r_prime, t_lower)) {
        try ts.append(int.Intersection{
            .t = t_lower,
            .shape_attrs = cyl.common_attrs,
            .normal = normalAt(cyl, ray.position(r, t_lower)),
        });
    }

    // Check for intersection between ray and upper cap by intersecting the ray
    // with the plane that functions as that cap.
    const t_upper = (cyl.maximum - r_prime.origin[1]) / r_prime.direction[1];
    if (checkCap(r_prime, t_upper)) {
        try ts.append(int.Intersection{
            .t = t_upper,
            .shape_attrs = cyl.common_attrs,
            .normal = normalAt(cyl, ray.position(r, t_upper)),
        });
    }
}

fn checkCap(r: ray.Ray, t: f64) bool {
    // Check if the intersection at `t` is within the radius of the unit
    // cylinder from the y-axis.
    const x = @mulAdd(f64, t, r.direction[0], r.origin[0]);
    const z = @mulAdd(f64, t, r.direction[2], r.origin[2]);
    return (x * x + z * z) <= 1;
}

pub fn normalAt(cyl: Cylinder, world_point: tup.Point) tup.Vector {
    const inverse = mat.inverse(cyl.common_attrs.transform);

    var object_normal: tup.Vector = undefined;
    const object_point = mat.mul(inverse, world_point);

    const distance = object_point[0] * object_point[0] + object_point[2] * object_point[2];
    if (distance < 1 and object_point[1] >= cyl.maximum - tup.epsilon) {
        object_normal = tup.vector(0, 1, 0);
    } else if (distance < 1 and object_point[1] <= cyl.minimum + tup.epsilon) {
        object_normal = tup.vector(0, -1, 0);
    } else {
        object_normal = tup.vector(object_point[0], 0, object_point[2]);
    }

    var world_normal = mat.mul(mat.transpose(inverse), object_normal);
    world_normal[3] = 0;

    return tup.normalize(world_normal);
}

test "a ray misses a cylinder" {
    const c = Cylinder{};

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    inline for (.{
        .{ .origin = tup.Point{1, 0, 0, 1}, .direction = tup.Vector{0, 1, 0, 0} },
        .{ .origin = tup.Point{0, 0, 0, 1}, .direction = tup.Vector{0, 1, 0, 0} },
        .{ .origin = tup.Point{0, 0, -5, 1}, .direction = tup.Vector{1, 1, 1, 0} },
    }) |x| {
        const r = ray.Ray{
            .origin = x.origin,
            .direction = tup.normalize(x.direction),
        };

        try intersect(&xs, c, r);
        try expectEqual(xs.items.len, 0);

        xs.items.len = 0;
    }
}

test "a ray strikes a cylinder" {
    const c = Cylinder{};

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    inline for (.{
        .{ .origin = tup.Point{1, 0, -5, 1}, .direction = tup.Vector{0, 0, 1, 0}, .t0 = 5, .t1 = 5 },
        .{ .origin = tup.Point{0, 0, -5, 1}, .direction = tup.Vector{0, 0, 1, 0}, .t0 = 4, .t1 = 6 },
        .{ .origin = tup.Point{0.5, 0, -5, 1}, .direction = tup.Vector{0.1, 1, 1, 0}, .t0 = 6.80798, .t1 = 7.08872 },
    }) |x| {
        const r = ray.Ray{
            .origin = x.origin,
            .direction = tup.normalize(x.direction),
        };

        try intersect(&xs, c, r);
        try expectEqual(xs.items.len, 2);
        try expectApproxEqAbs(xs.items[0].t, x.t0, 0.0001);
        try expectApproxEqAbs(xs.items[1].t, x.t1, 0.0001);

        xs.items.len = 0;
    }
}

test "normal vector on a cylinder" {
    const c = Cylinder{};
    inline for (.{
        .{ .point = tup.Point{1, 0, 0, 1}, .normal = tup.Vector{1, 0, 0, 0} },
        .{ .point = tup.Point{0, 5, -1, 1}, .normal = tup.Vector{0, 0, -1, 0} },
        .{ .point = tup.Point{0, -2, 1, 1}, .normal = tup.Vector{0, 0, 1, 0} },
        .{ .point = tup.Point{-1, 1, 0, 1}, .normal = tup.Vector{-1, 0, 0, 0} },
    }) |x| {
        try expectEqual(x.normal, normalAt(c, x.point));
    }
}

test "intersecting a constrained cylinder" {
    const c = Cylinder{
        .minimum = 1.0,
        .maximum = 2.0,
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    inline for (.{
        .{ .point = tup.Point{0, 1.5, 0, 1}, .direction = tup.Vector{0.1, 1, 0, 0}, .count = 0 },
        .{ .point = tup.Point{0, 3, -5, 1}, .direction = tup.Vector{0, 0, 1, 0}, .count = 0 },
        .{ .point = tup.Point{0, 0, -5, 1}, .direction = tup.Vector{0, 0, 1, 0}, .count = 0 },
        .{ .point = tup.Point{0, 2, -5, 1}, .direction = tup.Vector{0, 0, 1, 0}, .count = 0 },
        .{ .point = tup.Point{0, 1, -5, 1}, .direction = tup.Vector{0, 0, 1, 0}, .count = 0 },
        .{ .point = tup.Point{0, 1.5, -2, 1}, .direction = tup.Vector{0, 0, 1, 0}, .count = 2 },
    }) |x| {
        const r = ray.Ray{
            .origin = x.point,
            .direction = tup.normalize(x.direction),
        };

        try intersect(&xs, c, r);
        try expectEqual(xs.items.len, x.count);

        xs.items.len = 0;
    }
}

test "intersecting the caps of a closed cylinder" {
    const c = Cylinder{
        .minimum = 1.0,
        .maximum = 2.0,
        .closed = true,
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    inline for (.{
        // .{ .point = tup.Point{0, 0.5, 0.999, 1}, .direction = tup.Vector{0, 1, 0, 0}, .count = 2 },
        // .{ .point = tup.Point{0, 0.5, 1.001, 1}, .direction = tup.Vector{0, 1, 0, 0}, .count = 0 },
        .{ .point = tup.Point{0, 3, 0, 1}, .direction = tup.Vector{0, -1, 0, 0}, .count = 2 },
        .{ .point = tup.Point{0, 3, -2, 1}, .direction = tup.Vector{0, -1, 2, 0}, .count = 2 },
        .{ .point = tup.Point{0, 4, -2, 1}, .direction = tup.Vector{0, -1, 1, 0}, .count = 2 },
        .{ .point = tup.Point{0, 0, -2, 1}, .direction = tup.Vector{0, 1, 2, 0}, .count = 2 },
        .{ .point = tup.Point{0, -1, -2, 1}, .direction = tup.Vector{0, 1, 1, 0}, .count = 2 },
    }) |x| {
        const r = ray.Ray{
            .origin = x.point,
            .direction = tup.normalize(x.direction),
        };

        try intersect(&xs, c, r);
        try expectEqual(xs.items.len, x.count);

        xs.items.len = 0;
    }
}

test "the normal vector on a cylinder's end caps" {
    const c = Cylinder{
        .minimum = 1.0,
        .maximum = 2.0,
        .closed = true,
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    inline for (.{
        .{ .point = tup.Point{0, 1, 0, 1}, .normal = tup.Vector{0, -1, 0, 0} },
        .{ .point = tup.Point{0.5, 1, 0, 1}, .normal = tup.Vector{0, -1, 0, 0} },
        .{ .point = tup.Point{0, 1, 0.5, 1}, .normal = tup.Vector{0, -1, 0, 0} },
        .{ .point = tup.Point{0, 2, 0, 1}, .normal = tup.Vector{0, 1, 0, 0} },
        .{ .point = tup.Point{0.5, 2, 0, 1}, .normal = tup.Vector{0, 1, 0, 0} },
        .{ .point = tup.Point{0, 2, 0.5, 1}, .normal = tup.Vector{0, 1, 0, 0} },
    }) |x| {
        try expectEqual(x.normal, normalAt(c, x.point));
    }
}
