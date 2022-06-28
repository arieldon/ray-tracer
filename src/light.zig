const std = @import("std");
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const tup = @import("tuple.zig");

pub const PointLight = struct {
    position: tup.Point,
    intensity: cnv.Color,
};

pub fn pointLight(position: tup.Point, intensity: cnv.Color) PointLight {
    return .{
        .position = position,
        .intensity = intensity,
    };
}

test "a point light has a position and intensity" {
    const intensity = cnv.color(1, 1, 1);
    const position = tup.point(0, 0, 0);
    const light = pointLight(position, intensity);
    try expectEqual(light.position, position);
    try expectEqual(light.intensity, intensity);
}
