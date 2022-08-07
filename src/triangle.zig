const std = @import("std");
const int = @import("intersection.zig");
const mat = @import("matrix.zig");
const ray = @import("ray.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

pub const Triangle = struct {
    common_attrs: shp.CommonShapeAttributes = .{},

    p0: tup.Point,
    p1: tup.Point,
    p2: tup.Point,
    e0: tup.Vector,
    e1: tup.Vector,

    normal: tup.Vector,

    pub fn init(p0: tup.Point, p1: tup.Point, p2: tup.Point) Triangle {
        const e0 = p1 - p0;
        const e1 = p2 - p0;
        return Triangle{
            .p0 = p0,
            .p1 = p1,
            .p2 = p2,
            .e0 = e0,
            .e1 = e1,
            .normal = tup.normalize(tup.cross(e1, e0)),
        };
    }

    pub fn intersect(self: Triangle, r: ray.Ray, xs: *std.ArrayList(int.Intersection)) !void {
        const r_prime = ray.transform(r, mat.inverse(self.common_attrs.transform));

        const dir_cross_e1 = tup.cross(r_prime.direction, self.e1);
        const det = tup.dot(self.e0, dir_cross_e1);
        if (@fabs(det) < tup.epsilon) return;

        const f = 1.0 / det;
        const p0_to_origin = r_prime.origin - self.p0;
        const u = f * tup.dot(p0_to_origin, dir_cross_e1);
        if (u < 0 or u > 1) return;

        const origin_cross_e0 = tup.cross(p0_to_origin, self.e0);
        const v = f * tup.dot(r_prime.direction, origin_cross_e0);
        if (v < 0 or (u + v) > 1) return;

        const t = f * tup.dot(self.e1, origin_cross_e0);
        try xs.append(int.Intersection{
            .t = t,
            .shape_attrs = self.common_attrs,
            .normal = normalAt(self, ray.position(r, t)),
        });
    }

    pub fn normalAt(self: Triangle, world_point: tup.Point) tup.Vector {
        _ = world_point;

        const inverse = mat.inverse(self.common_attrs.transform);

        var world_normal = mat.mul(mat.transpose(inverse), self.normal);
        world_normal[3] = 0;

        return tup.normalize(world_normal);
    }
};
