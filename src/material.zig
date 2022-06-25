const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");

pub const Material = struct {
    color: cnv.Color,
    ambient: f32,
    diffuse: f32,
    specular: f32,
    shininess: f32,
};

pub fn material() Material {
    return .{
        .color = cnv.color(1, 1, 1),
        .ambient = 0.1,
        .diffuse = 0.9,
        .specular = 0.9,
        .shininess = 200.0,
    };
}

test "the default material" {
    const m = material();
    try expectEqual(m.color, cnv.color(1, 1, 1));
    try expectEqual(m.ambient, 0.1);
    try expectEqual(m.diffuse, 0.9);
    try expectEqual(m.specular, 0.9);
    try expectEqual(m.shininess, 200.0);
}
