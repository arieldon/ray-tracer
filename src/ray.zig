const std = @import("std");
const tup = @import("tuple.zig");
const mat = @import("matrix.zig");

pub const Ray = struct {
    origin: tup.Point,
    direction: tup.Vector,

    pub fn position(r: Ray, t: f32) tup.Point {
        return r.origin + r.direction * @splat(4, t);
    }

    pub fn transform(r: Ray, m: mat.Matrix) Ray {
        return .{
            .origin = mat.mul(m, r.origin),
            .direction = mat.mul(m, r.direction),
        };
    }
};
