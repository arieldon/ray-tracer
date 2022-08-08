const std = @import("std");
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

pub const Sphere = struct {
    common_attrs: shp.CommonShapeAttributes = .{},

    pub fn intersect(self: Sphere, r: ray.Ray, xs: *std.ArrayList(int.Intersection)) !void {
        // Transform ray instead of sphere because fundamentally it's the distance
        // and orientation between the two that matters. This way, the sphere
        // technically remains a unit sphere, which preserves ease of use, but
        // transformations may still be applied to it to alter its appearance in
        // the scene.
        const r_prime = ray.transform(r, mat.inverse(self.common_attrs.transform));

        // Calculate the vector from the center of the sphere to the origin of the
        // ray, where the sphere is a unit sphere and thus centered about the
        // origin with a radius of one.
        const sphere_to_ray = r_prime.origin - tup.point(0, 0, 0);

        // Calculate the variables in the discriminant (b^2 - 4ac) from the
        // quadratic formula algebraically. In this case, the equation in quadratic
        // form derives from the equation of a sphere centered about the origin:
        // P^2 - R^2 = 0, where P is some point (x, y, z) on the coordinate plane
        // and R is the radius of the unit sphere. Replace P with the equation for
        // a point along a ray: P(t) = O + tD, where O and D represent the origin
        // and direction of the ray, respectively. Expand the expression and
        // rearrange the variables to match the following table.
        //      a <- D^2
        //      b <- 2 * D . O
        //      c <- O^2 - R^2
        const a = tup.dot(r_prime.direction, r_prime.direction);
        const b = 2 * tup.dot(r_prime.direction, sphere_to_ray);
        const c = tup.dot(sphere_to_ray, sphere_to_ray) - 1;

        // Use the discriminant to determine the number of intersections and their
        // t values if they exist.
        const discriminant = b * b - 4 * a * c;
        if (discriminant >= 0) {
            // When the ray intersects a sphere at two unique points, both t values
            // will be unique. When the ray is tangent to the sphere and it
            // intersects at one point, both t values will be the same. In this
            // latter case, the discriminant is zero.
            const t0 = (-b - @sqrt(discriminant)) / (2 * a);
            const t1 = (-b + @sqrt(discriminant)) / (2 * a);
            try xs.appendSlice(&[_]int.Intersection{
                .{ .t = t0, .shape = .{ .sphere = self } },
                .{ .t = t1, .shape = .{ .sphere = self } },
            });
        }
    }

    pub fn normalAt(sphere: Sphere, world_point: tup.Point) tup.Vector {
        const inverse = mat.inverse(sphere.common_attrs.transform);

        // Convert the point from world space to object space. Because the sphere
        // may be transformed -- skewed, translated, scaled, or what not -- in
        // world space, it's necessary to calculate the surface normal vector
        // relative to the sphere rather than the world.
        const object_point = mat.mul(inverse, world_point);

        // With the point in object space, it's easy to calculate the surface
        // normal vector: the center of the sphere from the point in question. With
        // the base assumption that all spheres are unit spheres in this ray
        // tracer, the center of the sphere is the origin of the coordinate plane.
        const object_normal = object_point - tup.point(0, 0, 0);

        // Convert the surface normal vector from object space to world space.
        // Multiply by the transpose of the inverse to keep the surface normal
        // vector perpendicular to the surface of the sphere.
        var world_normal = mat.mul(mat.transpose(inverse), object_normal);

        // HACK: Reset w to 0 to accommodate translation transformations. It's more
        // proper to multiply by the inverse transpose of the submatrix in the
        // previous calculation, but this achieves the same result, faster.
        world_normal[3] = 0;

        return tup.normalize(world_normal);
    }
};
