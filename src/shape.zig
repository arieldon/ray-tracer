const std = @import("std");
const expectEqual = std.testing.expectEqual;
const mat = @import("matrix.zig");
const mtl = @import("material.zig");

pub const ShapeType = enum {
    sphere,
    plane,
};

pub const Shape = struct {
    shape_type: ShapeType,
    material: mtl.Material = mtl.Material{},
    transform: mat.Matrix = mat.identity,
};

inline fn testShape() Shape { return .{ .shape_type = .sphere }; }

test "the default transformation" {
    var s = testShape();
    try expectEqual(s.transform, mat.identity);
}

test "assigning a transformation" {
    var s = testShape();
    s.transform = mat.translation(2, 3, 4);
    try expectEqual(s.transform, mat.translation(2, 3, 4));
}

test "the default material" {
    var s = testShape();
    try expectEqual(s.material, mtl.Material{});
}

test "assigning a material" {
    var s = testShape();
    var m = mtl.Material{ .ambient = 1 };
    s.material = m;
    try expectEqual(s.material, m);
}
