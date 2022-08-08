const std = @import("std");
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const mat = @import("matrix.zig");
const shp = @import("shape.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

const black = cnv.Color{0, 0, 0};
const white = cnv.Color{1, 1, 1};

pub const Pattern = @This();

a: cnv.Color,
b: cnv.Color,
transform: mat.Matrix = mat.identity,
color_map: fn (pattern: *const Pattern, point: tup.Point) cnv.Color,

pub inline fn at(self: *const Pattern, point: tup.Point) cnv.Color {
    return self.color_map(self, point);
}

pub fn atShape(
    self: *const Pattern,
    shape_attrs: shp.CommonShapeAttributes,
    world_point: tup.Point,
) cnv.Color {
    const object_point = mat.mul(mat.inverse(shape_attrs.transform), world_point);
    const pattern_point = mat.mul(mat.inverse(self.transform), object_point);
    return self.at(pattern_point);
}

pub fn stripe(pattern: *const Pattern, point: tup.Point) cnv.Color {
    return if (@mod(@floor(point[0]), 2) == 0) pattern.a else pattern.b;
}

pub fn gradient(pattern: *const Pattern, point: tup.Point) cnv.Color {
    const distance = pattern.b - pattern.a;
    const fraction = point[0] - @floor(point[0]);
    return pattern.a + distance * @splat(3, fraction);
}

pub fn ring(pattern: *const Pattern, point: tup.Point) cnv.Color {
    const c = @floor(@sqrt(point[0] * point[0] + point[2] * point[2]));
    return if (@mod(c, 2) == 0) pattern.a else pattern.b;
}

pub fn checker(pattern: *const Pattern, point: tup.Point) cnv.Color {
    const c = @floor(point[0]) + @floor(point[1]) + @floor(point[2]);
    return if (@mod(c, 2) == 0) pattern.a else pattern.b;
}
