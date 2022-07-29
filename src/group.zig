const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const con = @import("cone.zig");
const cub = @import("cube.zig");
const cyl = @import("cylinder.zig");
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const pln = @import("plane.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

/// Store shapes together to transform them as a single unit.
pub const Group = struct {
    /// Transform to apply to all shapes in the group.
    transform: mat.Matrix = mat.identity,

    /// Store a dynamic array of shapes in the group.
    shapes: std.ArrayList(shp.Shape),

    /// Store a dynamic array of subgroups.
    subgroups: std.ArrayList(Group),

    pub fn init(allocator: std.mem.Allocator, transform: mat.Matrix) Group {
        return .{
            .transform = transform,
            .shapes = std.ArrayList(shp.Shape).init(allocator),
            .subgroups = std.ArrayList(Group).init(allocator),
        };
    }

    pub fn deinit(self: *Group) void {
        self.shapes.deinit();
        for (self.subgroups.items) |*subgroup| subgroup.deinit();
        self.subgroups.deinit();
    }
};

pub fn intersect(ts: *std.ArrayList(int.Intersection), g: Group, r: ray.Ray) !void {
    for (g.shapes.items) |shape| {
        switch (shape) {
            .cone => |cone| {
                var transformed_cone = cone;
                transformed_cone.common_attrs.transform = mat.mul(
                    g.transform, cone.common_attrs.transform);
                try con.intersect(ts, transformed_cone, r);
            },
            .cube => |cube| {
                var transformed_cube = cube;
                transformed_cube.common_attrs.transform = mat.mul(
                    g.transform, cube.common_attrs.transform);
                try cub.intersect(ts, transformed_cube, r);
            },
            .cylinder => |cylinder| {
                var transformed_cylinder = cylinder;
                transformed_cylinder.common_attrs.transform = mat.mul(
                    g.transform, cylinder.common_attrs.transform);
                try cyl.intersect(ts, transformed_cylinder, r);
            },
            .plane => |plane| {
                var transformed_plane = plane;
                transformed_plane.common_attrs.transform = mat.mul(
                    g.transform, plane.common_attrs.transform);
                try pln.intersect(ts, transformed_plane, r);
            },
            .sphere => |sphere| {
                var transformed_sphere = sphere;
                transformed_sphere.common_attrs.transform = mat.mul(
                    g.transform, sphere.common_attrs.transform);
                try sph.intersect(ts, transformed_sphere, r);
            },
        }
    }

    for (g.subgroups.items) |*subgroup| {
        // Apply transform of encompassing group to this subgroup.
        const original_transform = subgroup.transform;
        subgroup.transform = mat.mul(g.transform, original_transform);

        // FIXME Resolve error set instead of crashing.
        intersect(ts, subgroup.*, r) catch unreachable;

        // Restore the original transform of the subgroup for the next test for
        // intersections.
        subgroup.transform = original_transform;
    }

    int.sortIntersections(ts.items);
}

test "intersecting a ray with an empty group" {
    const r = ray.Ray{
        .origin = tup.point(0, 0, 0),
        .direction = tup.vector(0, 0, 1),
    };

    var g = Group.init(std.testing.allocator, mat.identity);
    defer g.deinit();

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try intersect(&xs, g, r);
    try expectEqual(xs.items.len, 0);
}

test "intersecting a ray with a nonempty group" {
    const s1 = sph.Sphere{};
    const s2 = sph.Sphere{ .common_attrs = .{ .transform = mat.translation(0, 0, -3) } };
    const s3 = sph.Sphere{ .common_attrs = .{ .transform = mat.translation(5, 0, 0) } };
    const r = ray.Ray{
        .origin = tup.point(0, 0, -5),
        .direction = tup.vector(0, 0, 1),
    };

    var g = Group.init(std.testing.allocator, mat.identity);
    defer g.deinit();

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try g.shapes.append(shp.Shape{ .sphere = s1 });
    try g.shapes.append(shp.Shape{ .sphere = s2 });
    try g.shapes.append(shp.Shape{ .sphere = s3 });
    try intersect(&xs, g, r);

    try expectEqual(xs.items.len, 4);
    try expectEqual(xs.items[0].shape_attrs, s2.common_attrs);
    try expectEqual(xs.items[1].shape_attrs, s2.common_attrs);
    try expectEqual(xs.items[2].shape_attrs, s1.common_attrs);
    try expectEqual(xs.items[3].shape_attrs, s1.common_attrs);
}

test "intersecting a transformed group" {
    const s = sph.Sphere{
        .common_attrs = .{
            .transform = mat.translation(5, 0, 0),
        },
    };
    const r = ray.Ray{
        .origin = tup.point(10, 0, -10),
        .direction = tup.vector(0, 0, 1),
    };

    var g = Group.init(std.testing.allocator, mat.scaling(2, 2, 2));
    defer g.deinit();

    var xs = std.ArrayList(int.Intersection).init(std.testing.allocator);
    defer xs.deinit();

    try g.shapes.append(shp.Shape{ .sphere = s });
    try intersect(&xs, g, r);
    try expectEqual(xs.items.len, 2);
}
