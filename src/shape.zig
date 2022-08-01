const std = @import("std");
const mat = @import("matrix.zig");
const mtl = @import("material.zig");

pub const CommonShapeAttributes = struct {
    transform: mat.Matrix = mat.identity,
    material: mtl.Material = mtl.Material{},
};
