const std = @import("std");
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

// A plane is an infinite 2D flat surface. It defaults to the xz-axis, but it
// may be transformed to appear in any orientation.
pub const Plane = struct {
    common_attrs: shp.CommonShapeAttributes = .{},

    pub fn intersect(self: Plane, r: ray.Ray, xs: *std.ArrayList(int.Intersection)) !void {
        // Transform the ray by the inverse of the transformation of the plane to
        // effectively apply the transformation of the plane without losing the
        // convenience of the "unit" plane.
        const r_prime = ray.transform(r, mat.inverse(self.common_attrs.transform));

        // A ray parallel to a plane will not intersect it at any point. A ray with
        // a y-component of zero is parallel to the plane since the plane sits on
        // the xz-axis, and a plane in the xz axis doesn't have a rate of change in
        // the y-axis.
        if (@fabs(r_prime.direction[1]) < tup.epsilon) return;

        // Compute the intersection of the transformed ray with the plane.
        const t = -r_prime.origin[1] / r_prime.direction[1];
        try xs.append(int.Intersection{ .t = t, .shape = .{ .plane = self } });
    }

    pub fn normalAt(self: Plane, world_point: tup.Point) tup.Vector {
        // The point in the world isn't necessary since the normal vector of a
        // plane remains constant at all points.
        _ = world_point;

        // The surface normal vector of a plane remains constant at all points
        // because a plane doesn't curve.
        var n = mat.mul(mat.transpose(mat.inverse(self.common_attrs.transform)), tup.vector(0, 1, 0));

        // HACK: Reset w to 0 to accommodate translation transformations. It's more
        // correct to multiply by the inverse transpose of the submatrix in the
        // previous calculation, but this achieves the same result with fewer
        // computations.
        n[3] = 0;

        return tup.normalize(n);
    }
};
