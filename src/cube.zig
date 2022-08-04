const std = @import("std");
const expectEqual = std.testing.expectEqual;
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

pub const Cube = struct {
    common_attrs: shp.CommonShapeAttributes = .{},
};

const TMinMax = struct {
    tmin: f64,
    tmax: f64,
};

pub fn intersect(ts: *std.ArrayList(int.Intersection), c: Cube, r: ray.Ray) !void {
    const r_prime = ray.transform(r, mat.inverse(c.common_attrs.transform));

    const x = checkAxis(r_prime.origin[0], r_prime.direction[0]);
    const y = checkAxis(r_prime.origin[1], r_prime.direction[1]);
    const z = checkAxis(r_prime.origin[2], r_prime.direction[2]);

    const tmin = @maximum(x.tmin, @maximum(y.tmin, z.tmin));
    const tmax = @minimum(x.tmax, @minimum(y.tmax, z.tmax));

    if (tmin > tmax) return;

    try ts.appendSlice(&[_]int.Intersection{
        .{ .t = tmin, .shape_attrs = c.common_attrs, .normal = normalAt(c, ray.position(r, tmin)) },
        .{ .t = tmax, .shape_attrs = c.common_attrs, .normal = normalAt(c, ray.position(r, tmax)) },
    });
}

fn checkAxis(origin: f64, direction: f64) TMinMax {
    const tmin_numerator = -1 - origin;
    const tmax_numerator = 1 - origin;

    var tmin: f64 = undefined;
    var tmax: f64 = undefined;
    if (@fabs(direction) >= tup.epsilon) {
        tmin = tmin_numerator / direction;
        tmax = tmax_numerator / direction;
    } else {
        tmin = tmin_numerator * std.math.inf_f64;
        tmax = tmax_numerator * std.math.inf_f64;
    }

    return if (tmin > tmax) .{ .tmin = tmax, .tmax = tmin } else .{ .tmin = tmin, .tmax = tmax };
}

pub fn normalAt(c: Cube, world_point: tup.Point) tup.Vector {
    const inverse = mat.inverse(c.common_attrs.transform);
    const object_point = mat.mul(inverse, world_point);

    const x = @fabs(object_point[0]);
    const y = @fabs(object_point[1]);
    const z = @fabs(object_point[2]);
    const maxc = @maximum(x, @maximum(y, z));

    const object_normal =
        if (maxc == x) tup.vector(object_point[0], 0, 0)
        else if (maxc == y) tup.vector(0, object_point[1], 0)
        else if (maxc == z) tup.vector(0, 0, object_point[2])
        else unreachable;

    return tup.normalize(mat.mul(mat.transpose(inverse), object_normal));
}

test "a ray intersects a cube" {
    const c = Cube{};

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    // NOTE For some reason, the program segfaults if origin and direction are
    // defined with the functions that automatically set the w component or the
    // last component of the vector.
    inline for (.{
        .{ .origin = tup.Point{5, 0.5, 0, 1}, .direction = tup.Vector{-1, 0, 0, 0}, .t1 = 4, .t2 = 6 },
        .{ .origin = tup.Point{-5, 0.5, 0, 1}, .direction = tup.Vector{1, 0, 0, 0}, .t1 = 4, .t2 = 6 },
        .{ .origin = tup.Point{0.5, 5, 0, 1}, .direction = tup.Vector{0, -1, 0, 0}, .t1 = 4, .t2 = 6 },
        .{ .origin = tup.Point{0.5, -5, 0, 1}, .direction = tup.Vector{0, 1, 0, 0}, .t1 = 4, .t2 = 6 },
        .{ .origin = tup.Point{0.5, 0, 5, 1}, .direction = tup.Vector{0, 0, -1, 0}, .t1 = 4, .t2 = 6 },
        .{ .origin = tup.Point{0.5, 0, -5, 1}, .direction = tup.Vector{0, 0, 1, 0}, .t1 = 4, .t2 = 6 },
        .{ .origin = tup.Point{0, 0.5, 0, 1}, .direction = tup.Vector{0, 0, 1, 0}, .t1 = -1, .t2 = 1 },
    }) |x| {
        const r = ray.Ray{
            .origin = x.origin,
            .direction = x.direction
        };

        try intersect(&xs, c, r);
        try expectEqual(xs.items.len, 2);
        try expectEqual(xs.items[0].t, x.t1);
        try expectEqual(xs.items[1].t, x.t2);

        xs.items.len = 0;
    }
}

test "a ray misses a cube" {
    const c = Cube{};

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    inline for (.{
        .{ .origin = tup.Point{-2, 0, 0, 1}, .direction = tup.Vector{0.2673, 0.5345, 0.8018, 0} },
        .{ .origin = tup.Point{0, -2, 0, 1}, .direction = tup.Vector{0.8018, 0.2673, 0.5345, 0} },
        .{ .origin = tup.Point{0, 0, -2, 1}, .direction = tup.Vector{0.5345, 0.8018, 0.2673, 0} },
        .{ .origin = tup.Point{2, 0, 2, 1}, .direction = tup.Vector{0, 0, -1, 0} },
        .{ .origin = tup.Point{0, 2, 2, 1}, .direction = tup.Vector{0, -1, 0, 0} },
        .{ .origin = tup.Point{2, 2, 0, 1}, .direction = tup.Vector{-1, 0, 0, 0} },
    }) |x| {
        const r = ray.Ray{
            .origin = x.origin,
            .direction = x.direction,
        };

        try intersect(&xs, c, r);
        try expectEqual(xs.items.len, 0);

        xs.items.len = 0;
    }
}

test "the normal on the surface of a cube" {
    const c = Cube{};
    inline for (.{
        .{ .point = tup.Point{1, 0.5, -0.8, 1}, .normal = tup.Vector{1, 0, 0, 0} },
        .{ .point = tup.Point{-1, -0.2, 0.9, 1}, .normal = tup.Vector{-1, 0, 0, 0} },
        .{ .point = tup.Point{-0.4, 1, -0.1, 1}, .normal = tup.Vector{0, 1, 0, 0} },
        .{ .point = tup.Point{0.3, -1, -0.7, 1}, .normal = tup.Vector{0, -1, 0, 0} },
        .{ .point = tup.Point{-0.6, 0.3, 1, 1}, .normal = tup.Vector{0, 0, 1, 0} },
        .{ .point = tup.Point{1, 1, 1, 1}, .normal = tup.Vector{1, 0, 0, 0} },
        .{ .point = tup.Point{-1, -1, -1, 1}, .normal = tup.Vector{-1, 0, 0, 0} },
    }) |x| {
        const normal = normalAt(c, x.point);
        try expectEqual(x.normal, normal);
    }
}
