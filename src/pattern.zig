const std = @import("std");
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const mat = @import("matrix.zig");
const shp = @import("shape.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

const black = cnv.color(0, 0, 0);
const white = cnv.color(1, 1, 1);

pub const StripePattern = struct {
    a: cnv.Color = white,
    b: cnv.Color = black,
    transform: mat.Matrix = mat.identity,

    pub fn stripeAt(self: *const StripePattern, point: tup.Point) cnv.Color {
        return if (@mod(@floor(point[0]), 2) == 0) self.a else self.b;
    }

    pub fn stripeAtShape(self: *const StripePattern, shape: shp.Shape, world_point: tup.Point) cnv.Color {
        const object_point = mat.mul(mat.inverse(shape.transform), world_point);
        const pattern_point = mat.mul(mat.inverse(self.transform), object_point);
        return self.stripeAt(pattern_point);
    }
};

test "creating a stripe pattern" {
    const pattern = StripePattern{ .a = white, .b = black };
    try expectEqual(pattern.a, white);
    try expectEqual(pattern.b, black);
}

test "a stripe pattern is constant in y" {
    const pattern = StripePattern{ .a = white, .b = black };
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(0, 1, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(0, 2, 0)), white);
}

test "a stripe pattern is constant in z" {
    const pattern = StripePattern{ .a = white, .b = black };
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 1)), white);
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 2)), white);
}

test "a striple pattern alternates in x" {
    const pattern = StripePattern{ .a = white, .b = black };
    try expectEqual(pattern.stripeAt(tup.point(0, 0, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(0.9, 0, 0)), white);
    try expectEqual(pattern.stripeAt(tup.point(1, 0, 0)), black);
    try expectEqual(pattern.stripeAt(tup.point(-0.1, 0, 0)), black);
    try expectEqual(pattern.stripeAt(tup.point(-1, 0, 0)), black);
    try expectEqual(pattern.stripeAt(tup.point(-1.1, 0, 0)), white);
}

test "stripes with an object transformation" {
    const sphere = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .transform = mat.scaling(2, 2, 2),
        },
    };
    const pattern = StripePattern{};

    const c = pattern.stripeAtShape(sphere.shape, tup.point(1.5, 0, 0));
    try expectEqual(c, white);
}

test "stripes with a pattern transformation" {
    const sphere = sph.Sphere{};
    const pattern = StripePattern{ .transform = mat.scaling(2, 2, 2) };

    const c = pattern.stripeAtShape(sphere.shape, tup.point(1.5, 0, 0));
    try expectEqual(c, white);
}

test "stripes with both an object and a pattern transformation" {
    const sphere = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .transform = mat.scaling(2, 2, 2)
        }
    };
    const pattern = StripePattern{ .transform = mat.translation(0.5, 0, 0) };

    const c = pattern.stripeAtShape(sphere.shape, tup.point(2.5, 0, 0));
    try expectEqual(c, white);
}
