const std = @import("std");
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

pub const Cone = struct {
    common_attrs: shp.CommonShapeAttributes = .{},
    minimum: f32 = -std.math.inf_f32,
    maximum: f32 = std.math.inf_f32,
    closed: bool = false,

    pub fn intersect(self: Cone, r: ray.Ray, xs: *std.ArrayList(int.Intersection)) !void {
        const r_prime = r.transform(mat.inverse(self.common_attrs.transform));

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
        if (std.math.approxEqAbs(f32, a, 0, tup.epsilon)) {
            if (std.math.approxEqAbs(f32, b, 0, tup.epsilon)) {
                // Ray misses the cone entirely when both a and b are zero.
                try self.intersectCaps(r_prime, xs);
                return;
            } else {
                const t = -c / (2 * b);
                try xs.append(int.Intersection{ .t = t, .shape = .{ .cone = self } });
                try self.intersectCaps(r_prime, xs);
                return;
            }
        }

        const discriminant = b * b - 4 * a * c;
        if (discriminant < 0) {
            try self.intersectCaps(r_prime, xs);
            return;
        }

        var t0 = (-b - @sqrt(discriminant)) / (2 * a);
        var t1 = (-b + @sqrt(discriminant)) / (2 * a);
        if (t0 > t1) std.mem.swap(f32, &t0, &t1);

        const y0 = @mulAdd(f32, t0, r_prime.direction[1], r_prime.origin[1]);
        if (self.minimum < y0 and y0 < self.maximum) {
            try xs.append(int.Intersection{ .t = t0, .shape = .{ .cone = self } });
        }

        const y1 = @mulAdd(f32, t1, r_prime.direction[1], r_prime.origin[1]);
        if (self.minimum < y1 and y1 < self.maximum) {
            try xs.append(int.Intersection{ .t = t1, .shape = .{ .cone = self } });
        }

        try self.intersectCaps(r_prime, xs);
    }

    fn intersectCaps(self: Cone, r_prime: ray.Ray, xs: *std.ArrayList(int.Intersection)) !void {
        if (!self.closed or std.math.approxEqAbs(f32, r_prime.direction[1], 0, tup.epsilon)) return;

        // Check for intersection between ray and lower cap by intersecting the ray
        // with the plane that functions as this cap.
        const t_lower = (self.minimum - r_prime.origin[1]) / r_prime.direction[1];
        if (checkCap(r_prime, t_lower, self.minimum)) {
            try xs.append(int.Intersection{ .t = t_lower, .shape = .{ .cone = self } });
        }

        // Check for intersection between ray and upper cap by intersecting the ray
        // with the plane that functions as that cap.
        const t_upper = (self.maximum - r_prime.origin[1]) / r_prime.direction[1];
        if (checkCap(r_prime, t_upper, self.maximum)) {
            try xs.append(int.Intersection{ .t = t_upper, .shape = .{ .cone = self } });
        }
    }

    pub fn normalAt(self: Cone, world_point: tup.Point) tup.Vector {
        const inverse = mat.inverse(self.common_attrs.transform);

        var object_normal: tup.Vector = undefined;
        const object_point = mat.mul(inverse, world_point);

        const distance = object_point[0] * object_point[0] + object_point[2] * object_point[2];
        if (distance < self.maximum * self.maximum and object_point[1] >= self.maximum - tup.epsilon) {
            object_normal = tup.vector(0, 1, 0);
        } else if (distance < self.minimum * self.minimum and
                   object_point[1] <= self.minimum + tup.epsilon) {
            object_normal = tup.vector(0, -1, 0);
        } else {
            const y = if (object_point[1] > 0) -@sqrt(distance) else @sqrt(distance);
            object_normal = tup.vector(object_point[0], y, object_point[2]);
        }

        var world_normal = mat.mul(mat.transpose(inverse), object_normal);
        world_normal[3] = 0;

        return tup.normalize(world_normal);
    }
};

fn checkCap(r: ray.Ray, t: f32, y: f32) bool {
    // Check if the intersection at `t` is within the radius of the cone on the
    // y-axis.
    const x = @mulAdd(f32, t, r.direction[0], r.origin[0]);
    const z = @mulAdd(f32, t, r.direction[2], r.origin[2]);
    return (x * x + z * z) <= @fabs(y * y);
}
