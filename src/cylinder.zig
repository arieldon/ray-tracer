const std = @import("std");
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

    pub fn intersect(self: Cylinder, r: ray.Ray, xs: *std.ArrayList(int.Intersection)) !void {
        const r_prime = ray.transform(r, mat.inverse(self.common_attrs.transform));

        // Because the ray is parallel to the y-axis, it will not intersect the
        // walls of the cylinder at any point. It may however intersect its caps.
        const a = r_prime.direction[0] * r_prime.direction[0] +
                  r_prime.direction[2] * r_prime.direction[2];
        if (std.math.approxEqAbs(f64, a, 0, tup.epsilon)) {
            try self.intersectCaps(r_prime, xs);
            return;
        }

        const b = 2 * r_prime.origin[0] * r_prime.direction[0] +
                  2 * r_prime.origin[2] * r_prime.direction[2];
        const c = r_prime.origin[0] * r_prime.origin[0] + r_prime.origin[2] * r_prime.origin[2] - 1;

        const discriminant = b * b - 4 * a * c;
        if (discriminant < 0) {
            try self.intersectCaps(r_prime, xs);
            return;
        }

        var t0 = (-b - @sqrt(discriminant)) / (2 * a);
        var t1 = (-b + @sqrt(discriminant)) / (2 * a);
        if (t0 > t1) std.mem.swap(f64, &t0, &t1);

        const y0 = @mulAdd(f64, t0, r_prime.direction[1], r_prime.origin[1]);
        if (self.minimum < y0 and y0 < self.maximum) {
            try xs.append(int.Intersection{ .t = t0, .shape = .{ .cylinder = self } });
        }

        const y1 = @mulAdd(f64, t1, r_prime.direction[1], r_prime.origin[1]);
        if (self.minimum < y1 and y1 < self.maximum) {
            try xs.append(int.Intersection{ .t = t1, .shape = .{ .cylinder = self } });
        }

        try self.intersectCaps(r_prime, xs);
    }

    fn intersectCaps(self: Cylinder, r_prime: ray.Ray, xs: *std.ArrayList(int.Intersection)) !void {
        // Caps only exist on a closed cylinder. They're also only relevant if the
        // ray may intersect them at some point.
        if (!self.closed or std.math.approxEqAbs(f64, r_prime.direction[1], 0, tup.epsilon)) return;

        // Check for intersection between ray and lower cap by intersecting the ray
        // with the plane that functions as this cap.
        const t_lower = (self.minimum - r_prime.origin[1]) / r_prime.direction[1];
        if (checkCap(r_prime, t_lower)) {
            try xs.append(int.Intersection{ .t = t_lower, .shape = .{ .cylinder = self } });
        }

        // Check for intersection between ray and upper cap by intersecting the ray
        // with the plane that functions as that cap.
        const t_upper = (self.maximum - r_prime.origin[1]) / r_prime.direction[1];
        if (checkCap(r_prime, t_upper)) {
            try xs.append(int.Intersection{ .t = t_upper, .shape = .{ .cylinder = self } });
        }
    }

    pub fn normalAt(self: Cylinder, world_point: tup.Point) tup.Vector {
        const inverse = mat.inverse(self.common_attrs.transform);

        var object_normal: tup.Vector = undefined;
        const object_point = mat.mul(inverse, world_point);

        const distance = object_point[0] * object_point[0] + object_point[2] * object_point[2];
        if (distance < 1 and object_point[1] >= self.maximum - tup.epsilon) {
            object_normal = tup.vector(0, 1, 0);
        } else if (distance < 1 and object_point[1] <= self.minimum + tup.epsilon) {
            object_normal = tup.vector(0, -1, 0);
        } else {
            object_normal = tup.vector(object_point[0], 0, object_point[2]);
        }

        var world_normal = mat.mul(mat.transpose(inverse), object_normal);
        world_normal[3] = 0;

        return tup.normalize(world_normal);
    }
};

fn checkCap(r: ray.Ray, t: f64) bool {
    // Check if the intersection at `t` is within the radius of the unit
    // cylinder from the y-axis.
    const x = @mulAdd(f64, t, r.direction[0], r.origin[0]);
    const z = @mulAdd(f64, t, r.direction[2], r.origin[2]);
    return (x * x + z * z) <= 1;
}
