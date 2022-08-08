const std = @import("std");
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

pub const Cube = struct {
    common_attrs: shp.CommonShapeAttributes = .{},

    pub fn intersect(self: Cube, r: ray.Ray, xs: *std.ArrayList(int.Intersection)) !void {
        const r_prime = r.transform(mat.inverse(self.common_attrs.transform));

        const x = checkAxis(r_prime.origin[0], r_prime.direction[0]);
        const y = checkAxis(r_prime.origin[1], r_prime.direction[1]);
        const z = checkAxis(r_prime.origin[2], r_prime.direction[2]);

        const tmin = @maximum(x.tmin, @maximum(y.tmin, z.tmin));
        const tmax = @minimum(x.tmax, @minimum(y.tmax, z.tmax));

        if (tmin > tmax) return;
        try xs.appendSlice(&[_]int.Intersection{
            .{ .t = tmin, .shape = .{ .cube = self } },
            .{ .t = tmax, .shape = .{ .cube = self } },
        });
    }

    pub fn normalAt(self: Cube, world_point: tup.Point) tup.Vector {
        const inverse = mat.inverse(self.common_attrs.transform);
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
};

const TMinMax = struct {
    tmin: f64,
    tmax: f64,
};

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
