const std = @import("std");
const expectEqual = std.testing.expectEqual;
const expectApproxEqAbs = std.testing.expectApproxEqAbs;
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

pub const Cone = struct {
    common_attrs: shp.CommonShapeAttributes = .{},
    minimum: f64 = -std.math.inf_f64,
    maximum: f64 = std.math.inf_f64,
    closed: bool = false,
};

pub fn intersect(ts: *std.ArrayList(int.Intersection), cone: Cone, r: ray.Ray) !void {
    const r_prime = ray.transform(r, mat.inverse(cone.common_attrs.transform));

    const a = r_prime.direction[0] * r_prime.direction[0] -
              r_prime.direction[1] * r_prime.direction[1] +
              r_prime.direction[2] * r_prime.direction[2];
    const b = 2 * r_prime.origin[0] * r_prime.direction[0] -
              2 * r_prime.origin[1] * r_prime.direction[1] +
              2 * r_prime.origin[2] * r_prime.direction[2];
    const c = r_prime.origin[0] * r_prime.origin[0] -
              r_prime.origin[1] * r_prime.origin[1] +
              r_prime.origin[2] * r_prime.origin[2];

    // When a is zero, the ray is parallel to one of the cone's inward facing
    // edges. In this case, the ray may still intersect the other half of the
    // cone.
    if (std.math.approxEqAbs(f64, a, 0, tup.epsilon)) {
        if (std.math.approxEqAbs(f64, b, 0, tup.epsilon)) {
            // Ray misses the cone entirely when both a and b are zero.
            try intersectCaps(ts, cone, r, r_prime);
            return;
        } else {
            const t = -c / (2 * b);
            try ts.append(int.Intersection{
                .t = t,
                .shape_attrs = cone.common_attrs,
                .normal = normalAt(cone, ray.position(r, t)),
            });
            try intersectCaps(ts, cone, r, r_prime);
            return;
        }
    }

    const discriminant = b * b - 4 * a * c;
    if (discriminant < 0) {
        try intersectCaps(ts, cone, r, r_prime);
        return;
    }

    var t0 = (-b - @sqrt(discriminant)) / (2 * a);
    var t1 = (-b + @sqrt(discriminant)) / (2 * a);
    if (t0 > t1) std.mem.swap(f64, &t0, &t1);

    const y0 = @mulAdd(f64, t0, r_prime.direction[1], r_prime.origin[1]);
    if (cone.minimum < y0 and y0 < cone.maximum) {
        try ts.append(int.Intersection{
            .t = t0,
            .shape_attrs = cone.common_attrs,
            .normal = normalAt(cone, ray.position(r, t0)),
        });
    }

    const y1 = @mulAdd(f64, t1, r_prime.direction[1], r_prime.origin[1]);
    if (cone.minimum < y1 and y1 < cone.maximum) {
        try ts.append(int.Intersection{
            .t = t1,
            .shape_attrs = cone.common_attrs,
            .normal = normalAt(cone, ray.position(r, t1)),
        });
    }

    try intersectCaps(ts, cone, r, r_prime);
}

fn intersectCaps(
    ts: *std.ArrayList(int.Intersection),
    cone: Cone,
    r: ray.Ray,
    r_prime: ray.Ray,
) !void {
    if (!cone.closed or std.math.approxEqAbs(f64, r_prime.direction[1], 0, tup.epsilon)) return;

    // Check for intersection between ray and lower cap by intersecting the ray
    // with the plane that functions as this cap.
    const t_lower = (cone.minimum - r_prime.origin[1]) / r_prime.direction[1];
    if (checkCap(r_prime, t_lower, cone.minimum)) {
        try ts.append(int.Intersection{
            .t = t_lower,
            .shape_attrs = cone.common_attrs,
            .normal = normalAt(cone, ray.position(r, t_lower)),
        });
    }

    // Check for intersection between ray and upper cap by intersecting the ray
    // with the plane that functions as that cap.
    const t_upper = (cone.maximum - r_prime.origin[1]) / r_prime.direction[1];
    if (checkCap(r_prime, t_upper, cone.maximum)) {
        try ts.append(int.Intersection{
            .t = t_upper,
            .shape_attrs = cone.common_attrs,
            .normal = normalAt(cone, ray.position(r, t_upper)),
        });
    }
}

fn checkCap(r: ray.Ray, t: f64, y: f64) bool {
    // Check if the intersection at `t` is within the radius of the cone on the
    // y-axis.
    const x = @mulAdd(f64, t, r.direction[0], r.origin[0]);
    const z = @mulAdd(f64, t, r.direction[2], r.origin[2]);
    return (x * x + z * z) <= @fabs(y * y);
}

pub fn normalAt(cone: Cone, world_point: tup.Point) tup.Vector {
    const inverse = mat.inverse(cone.common_attrs.transform);

    var object_normal: tup.Vector = undefined;
    const object_point = mat.mul(inverse, world_point);

    const distance = object_point[0] * object_point[0] + object_point[2] * object_point[2];
    if (distance < cone.maximum * cone.maximum and object_point[1] >= cone.maximum - tup.epsilon) {
        object_normal = tup.vector(0, 1, 0);
    } else if (distance < cone.minimum * cone.minimum and object_point[1] <= cone.minimum + tup.epsilon) {
        object_normal = tup.vector(0, -1, 0);
    } else {
        const y = if (object_point[1] > 0) -@sqrt(distance) else @sqrt(distance);
        object_normal = tup.vector(object_point[0], y, object_point[2]);
    }

    var world_normal = mat.mul(mat.transpose(inverse), object_normal);
    world_normal[3] = 0;

    return tup.normalize(world_normal);
}

test "intersecting a cone with a ray" {
    const c = Cone{};

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    inline for (.{
        .{ .origin = tup.Point{0, 0, -5, 1}, .direction = tup.Vector{0, 0, 1, 0}, .t0 = 5, .t1 = 5 },
        .{ .origin = tup.Point{0, 0, -5, 1}, .direction = tup.Vector{1, 1, 1, 0}, .t0 = 8.66025, .t1 = 8.66025 },
        .{ .origin = tup.Point{1, 1, -5, 1}, .direction = tup.Vector{-0.5, -1, 1, 0}, .t0 = 4.55006, .t1 = 49.44994 },
    }) |x| {
        const r = ray.Ray{
            .origin = x.origin,
            .direction = tup.normalize(x.direction),
        };

        try intersect(&xs, c, r);
        try expectEqual(xs.items.len, 2);
        try expectApproxEqAbs(xs.items[0].t, x.t0, tup.epsilon);
        try expectApproxEqAbs(xs.items[1].t, x.t1, tup.epsilon);

        xs.items.len = 0;
    }
}

test "intersecting a cone with a ray parallel to one of its halves" {
    const c = Cone{};
    const r = ray.Ray{
        .origin = tup.point(0, 0, -1),
        .direction = tup.normalize(tup.vector(0, 1, 1)),
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, c, r);
    try expectEqual(xs.items.len, 1);
    try expectApproxEqAbs(xs.items[0].t, 0.35355, tup.epsilon);
}

test "intersecting a cone's end caps" {
    const c = Cone{
        .minimum = -0.5,
        .maximum = 0.5,
        .closed = true,
    };

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    inline for (.{
        .{ .origin = tup.Point{0, 0, -5, 1}, .direction = tup.Vector{0, 1, 0, 0}, .count = 0 },
        .{ .origin = tup.Point{0, 0, -0.25, 1}, .direction = tup.Vector{0, 1, 1, 0}, .count = 2 },
        .{ .origin = tup.Point{0, 0, -0.25, 1}, .direction = tup.Vector{0, 1, 0, 0}, .count = 4 },
    }) |x| {
        const r = ray.Ray{
            .origin = x.origin,
            .direction = tup.normalize(x.direction),
        };

        try intersect(&xs, c, r);
        try expectEqual(xs.items.len, x.count);

        xs.items.len = 0;
    }
}

test "computing the normal vector on a cone" {
    const c = Cone{};

    inline for (.{
        .{ .point = tup.Point{0, 0, 0, 1}, .normal = tup.Vector{0, 0, 0, 0} },
        .{ .point = tup.Point{1, 1, 1, 1}, .normal = tup.Vector{1, -@sqrt(2.0), 1, 0} },
        .{ .point = tup.Point{-1, -1, 0, 1}, .normal = tup.Vector{-1, 1, 0, 0} },
    }) |x| {
        const n = normalAt(c, x.point);
        try expectEqual(n, x.normal);
    }
}
