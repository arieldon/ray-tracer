const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const bnd = @import("bounds.zig");
const con = @import("cone.zig");
const cub = @import("cube.zig");
const cyl = @import("cylinder.zig");
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const pln = @import("plane.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const sph = @import("sphere.zig");
const tri = @import("triangle.zig");
const tup = @import("tuple.zig");

/// Store shapes together to transform them as a single unit.
pub const Group = struct {
    allocator: std.mem.Allocator,

    /// Transform to apply to all shapes in the group.
    transform: mat.Matrix = mat.identity,

    /// Use a bounding box to test if a ray intersects the group before testing
    /// ray-shape intersection for each shape within the group.
    bounding_box: ?bnd.Bounds = null,

    /// Store a dynamic array of each type of shape in the group.
    spheres: std.ArrayList(sph.Sphere),
    planes: std.ArrayList(pln.Plane),
    cubes: std.ArrayList(cub.Cube),
    cylinders: std.ArrayList(cyl.Cylinder),
    cones: std.ArrayList(con.Cone),
    triangles: std.ArrayList(tri.Triangle),

    /// Store a dynamic array of subgroups.
    subgroups: std.ArrayList(Group),

    pub fn init(allocator: std.mem.Allocator, transform: mat.Matrix) Group {
        return .{
            .allocator = allocator,
            .transform = transform,
            .spheres = std.ArrayList(sph.Sphere).init(allocator),
            .planes = std.ArrayList(pln.Plane).init(allocator),
            .cubes = std.ArrayList(cub.Cube).init(allocator),
            .cylinders = std.ArrayList(cyl.Cylinder).init(allocator),
            .cones = std.ArrayList(con.Cone).init(allocator),
            .triangles = std.ArrayList(tri.Triangle).init(allocator),
            .subgroups = std.ArrayList(Group).init(allocator),
        };
    }

    pub fn bound(self: *Group) void {
        self.bounding_box = bnd.boundGroup(self);
    }

    pub fn intersect(g: *const Group, r: ray.Ray, xs: *std.ArrayList(int.Intersection)) !void {
        // Test ray intersection for shapes in group if and only if the ray
        // intersects the group's bounding box.
        if (g.bounding_box == null or bnd.intersect(g.bounding_box.?, r)) {
            for (g.spheres.items) |sphere|
                try transformShape(sphere, g.transform).intersect(r, xs);
            for (g.planes.items) |plane|
                try transformShape(plane, g.transform).intersect(r, xs);
            for (g.cubes.items) |cube|
                try transformShape(cube, g.transform).intersect(r, xs);
            for (g.cylinders.items) |cylinder|
                try transformShape(cylinder, g.transform).intersect(r, xs);
            for (g.cones.items) |cone|
                try transformShape(cone, g.transform).intersect(r, xs);
            for (g.triangles.items) |triangle|
                try transformShape(triangle, g.transform).intersect(r, xs);

            for (g.subgroups.items) |*subgroup| {
                // Apply transform of encompassing group to this subgroup.
                const original_transform = subgroup.transform;
                subgroup.transform = mat.mul(g.transform, original_transform);

                // FIXME Resolve error set instead of crashing.
                subgroup.intersect(r, xs) catch unreachable;

                // Restore the original transform of the subgroup for the next test for
                // intersections.
                subgroup.transform = original_transform;
            }

            int.sortIntersections(xs.items);
        }
    }

    pub fn deinit(self: *Group) void {
        self.spheres.deinit();
        self.planes.deinit();
        self.cubes.deinit();
        self.cylinders.deinit();
        self.cones.deinit();
        self.triangles.deinit();
        for (self.subgroups.items) |*subgroup| subgroup.deinit();
        self.subgroups.deinit();
    }
};

fn transformShape(shape: anytype, transform: mat.Matrix) @TypeOf(shape) {
    var transformed_shape = shape;
    transformed_shape.common_attrs.transform = mat.mul(
        transform, shape.common_attrs.transform);
    return transformed_shape;
}
