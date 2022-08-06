const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const con = @import("cone.zig");
const cub = @import("cube.zig");
const cyl = @import("cylinder.zig");
const grp = @import("group.zig");
const mat = @import("matrix.zig");
const pln = @import("plane.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const sph = @import("sphere.zig");
const tri = @import("triangle.zig");
const tup = @import("tuple.zig");

/// Describe the minimum and maximum coordinates for the axis-aligned bounding
/// box. Use bounding boxes to reduce the number of intersection tests the ray
/// tracer performs by first testing if the current ray intersects a box
/// bounding a group of shapes and only then testing intersections of all
/// shapes in the group.
pub const Bounds = struct {
    minimum: tup.Point,
    maximum: tup.Point,
};

fn bound(comptime T: type, shape: T) Bounds {
    return switch (T) {
        sph.Sphere => boundSphere(shape),
        pln.Plane => boundPlane(shape),
        cub.Cube => boundCube(shape),
        cyl.Cylinder => boundCylinder(shape),
        con.Cone => boundCone(shape),
        tri.Triangle => boundTriangle(shape),
        grp.Group => boundGroup(shape),
        else => @compileError("Unable to bound type " ++ @typeName(T) ++ "."),
    };
}

inline fn boundSphere(sphere: sph.Sphere) Bounds {
    _ = sphere;
    return .{
        .minimum = tup.point(-1, -1, -1),
        .maximum = tup.point(1, 1, 1),
    };
}

inline fn boundPlane(plane: pln.Plane) Bounds {
    _ = plane;
    return .{
        .minimum = tup.point(-std.math.inf_f64, 0, -std.math.inf_f64),
        .maximum = tup.point(std.math.inf_f64, 0, std.math.inf_f64),
    };
}

inline fn boundCube(cube: cub.Cube) Bounds {
    _ = cube;
    return .{
        .minimum = tup.point(-1, -1, -1),
        .maximum = tup.point(1, 1, 1),
    };
}

inline fn boundCylinder(cylinder: cyl.Cylinder) Bounds {
    return .{
        .minimum = tup.point(-1, cylinder.minimum, -1),
        .maximum = tup.point(1, cylinder.maximum, 1),
    };
}

inline fn boundCone(cone: con.Cone) Bounds {
    const xz_bound = @maximum(@fabs(cone.minimum), @fabs(cone.maximum));
    return .{
        .minimum = tup.point(-xz_bound, cone.minimum, -xz_bound),
        .maximum = tup.point(xz_bound, cone.maximum, xz_bound),
    };
}

inline fn boundTriangle(triangle: tri.Triangle) Bounds {
    return .{
        .minimum = @minimum(triangle.p0, @minimum(triangle.p1, triangle.p2)),
        .maximum = @maximum(triangle.p0, @maximum(triangle.p1, triangle.p2)),
    };
}

pub fn boundGroup(group: *const grp.Group) Bounds {
    var group_bounds = Bounds{
        .minimum = tup.point(std.math.inf_f64, std.math.inf_f64, std.math.inf_f64),
        .maximum = tup.point(-std.math.inf_f64, -std.math.inf_f64, -std.math.inf_f64),
    };

    for (group.spheres.items) |sphere|
        mergeBounds(&group_bounds, transformShapeBounds(sphere, group.transform));
    for (group.planes.items) |plane|
        mergeBounds(&group_bounds, transformShapeBounds(plane, group.transform));
    for (group.cubes.items) |cube|
        mergeBounds(&group_bounds, transformShapeBounds(cube, group.transform));
    for (group.cylinders.items) |cylinder|
        mergeBounds(&group_bounds, transformShapeBounds(cylinder, group.transform));
    for (group.cones.items) |cone|
        mergeBounds(&group_bounds, transformShapeBounds(cone, group.transform));
    for (group.triangles.items) |triangle|
        mergeBounds(&group_bounds, transformShapeBounds(triangle, group.transform));
    for (group.subgroups.items) |*subgroup|
        mergeBounds(&group_bounds, transformGroupBounds(subgroup, group.transform));

    return group_bounds;
}

inline fn mergeBounds(a: *Bounds, b: Bounds) void {
    a.minimum = @minimum(a.minimum, b.minimum);
    a.maximum = @maximum(a.maximum, b.maximum);
}

inline fn expandBoundsToFitPoint(b: *Bounds, p: tup.Point) void {
    b.minimum = @minimum(b.minimum, p);
    b.maximum = @maximum(b.maximum, p);
}

fn transformBounds(b: Bounds, transform: mat.Matrix) Bounds {
    var b_prime = b;

    const points = [_]tup.Point{
        tup.Point{ b.minimum[0], b.minimum[1], b.maximum[2], 1},
        tup.Point{ b.minimum[0], b.maximum[1], b.minimum[2], 1},
        tup.Point{ b.minimum[0], b.maximum[1], b.maximum[2], 1},
        tup.Point{ b.maximum[0], b.minimum[1], b.minimum[2], 1},
        tup.Point{ b.maximum[0], b.minimum[1], b.maximum[2], 1},
        tup.Point{ b.maximum[0], b.maximum[1], b.minimum[2], 1},
    };
    for (points) |point| expandBoundsToFitPoint(&b_prime, mat.mul(transform, point));

    return b_prime;
}

fn transformShapeBounds(shape: anytype, transform: mat.Matrix) Bounds {
    const shape_bounds = bound(@TypeOf(shape), shape);
    return transformBounds(shape_bounds, mat.mul(transform, shape.common_attrs.transform));
}

fn transformGroupBounds(group: *grp.Group, transform: mat.Matrix) Bounds {
    return transformBounds(boundGroup(group), transform);
}

const TMinMax = struct {
    tmin: f64,
    tmax: f64,
};

pub fn intersect(bounds: Bounds, r: ray.Ray) bool {
    const x = checkAxis(bounds.minimum[0], bounds.maximum[0], r.origin[0], r.direction[0]);
    const y = checkAxis(bounds.minimum[1], bounds.maximum[1], r.origin[1], r.direction[1]);
    const z = checkAxis(bounds.minimum[2], bounds.maximum[2], r.origin[2], r.direction[2]);

    const tmin = @maximum(x.tmin, @maximum(y.tmin, z.tmin));
    const tmax = @minimum(x.tmax, @minimum(y.tmax, z.tmax));

    return tmin <= tmax;
}

fn checkAxis(min: f64, max: f64, origin: f64, direction: f64) TMinMax {
    const tmin_numerator = min - origin;
    const tmax_numerator = max - origin;

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

test "a ray intersects a bounding box" {
    const b = Bounds{
        .minimum = tup.point(-1, -1, -1),
        .maximum = tup.point(1, 1, 1),
    };

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
        try expect(intersect(b, r));
    }
}

test "a ray misses a bounding box" {
    const b = Bounds{
        .minimum = tup.point(-1, -1, -1),
        .maximum = tup.point(1, 1, 1),
    };

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
        try expect(!intersect(b, r));
    }
}

test "merge bounds" {
    var b0 = Bounds{
        .minimum = tup.point(-3, 1, 0),
        .maximum = tup.point(9, 6, 3),
    };
    var b1 = Bounds{
        .minimum = tup.point(7, -7, -3),
        .maximum = tup.point(11, 2, 4),
    };

    mergeBounds(&b0, b1);
    try expectEqual(tup.point(-3, -7, -3), b0.minimum);
    try expectEqual(tup.point(11, 6, 4), b0.maximum);
}

test "transform bounds from shape space to group space" {
    const s = sph.Sphere{};
    const b = transformShapeBounds(
        s, mat.mul(mat.rotationX(std.math.pi / 4.0), mat.rotationY(std.math.pi / 4.0)));

    try expect(tup.equal(b.minimum, tup.point(-1.4142, -1.7071, -1.7071)));
    try expect(tup.equal(b.maximum, tup.point(1.4142, 1.7071, 1.7071)));
}
