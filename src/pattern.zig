const std = @import("std");
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const mat = @import("matrix.zig");
const shp = @import("shape.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

const black = cnv.color(0, 0, 0);
const white = cnv.color(1, 1, 1);

pub const Pattern = struct {
    a: cnv.Color,
    b: cnv.Color,
    transform: mat.Matrix = mat.identity,
    color_map: fn (pattern: *const Self, point: tup.Point) cnv.Color,

    const Self = @This();

    pub inline fn at(self: *const Self, point: tup.Point) cnv.Color {
        return self.color_map(self, point);
    }

    pub fn atShape(self: *const Self, shape: shp.Shape, world_point: tup.Point) cnv.Color {
        const object_point = mat.mul(mat.inverse(shape.transform), world_point);
        const pattern_point = mat.mul(mat.inverse(self.transform), object_point);
        return self.at(pattern_point);
    }
};

pub fn stripe(pattern: *const Pattern, point: tup.Point) cnv.Color {
    return if (@mod(@floor(point[0]), 2) == 0) pattern.a else pattern.b;
}

test "creating a stripe pattern" {
    const pattern = Pattern{ .a = white, .b = black, .color_map = stripe };
    try expectEqual(pattern.a, white);
    try expectEqual(pattern.b, black);
}

test "a stripe pattern is constant in y" {
    const pattern = Pattern{ .a = white, .b = black, .color_map = stripe };
    try expectEqual(pattern.at(tup.point(0, 0, 0)), white);
    try expectEqual(pattern.at(tup.point(0, 1, 0)), white);
    try expectEqual(pattern.at(tup.point(0, 2, 0)), white);
}

test "a stripe pattern is constant in z" {
    const pattern = Pattern{ .a = white, .b = black, .color_map = stripe };
    try expectEqual(pattern.at(tup.point(0, 0, 0)), white);
    try expectEqual(pattern.at(tup.point(0, 0, 1)), white);
    try expectEqual(pattern.at(tup.point(0, 0, 2)), white);
}

test "a striple pattern alternates in x" {
    const pattern = Pattern{ .a = white, .b = black, .color_map = stripe };
    try expectEqual(pattern.at(tup.point(0, 0, 0)), white);
    try expectEqual(pattern.at(tup.point(0.9, 0, 0)), white);
    try expectEqual(pattern.at(tup.point(1, 0, 0)), black);
    try expectEqual(pattern.at(tup.point(-0.1, 0, 0)), black);
    try expectEqual(pattern.at(tup.point(-1, 0, 0)), black);
    try expectEqual(pattern.at(tup.point(-1.1, 0, 0)), white);
}

test "stripes with an object transformation" {
    const sphere = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .transform = mat.scaling(2, 2, 2),
        },
    };
    const pattern = Pattern{ .a = white, .b = black, .color_map = stripe };

    const c = pattern.atShape(sphere.shape, tup.point(1.5, 0, 0));
    try expectEqual(c, white);
}

test "stripes with a pattern transformation" {
    const sphere = sph.Sphere{};
    const pattern = Pattern{
        .a = white,
        .b = black,
        .transform = mat.scaling(2, 2, 2),
        .color_map = stripe,
    };

    const c = pattern.atShape(sphere.shape, tup.point(1.5, 0, 0));
    try expectEqual(c, white);
}

test "stripes with both an object and a pattern transformation" {
    const sphere = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .transform = mat.scaling(2, 2, 2)
        }
    };
    const pattern = Pattern{
        .a = white,
        .b = black,
        .transform = mat.translation(0.5, 0, 0),
        .color_map = stripe,
    };

    const c = pattern.atShape(sphere.shape, tup.point(2.5, 0, 0));
    try expectEqual(c, white);
}
