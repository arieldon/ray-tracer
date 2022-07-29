const std = @import("std");
const con = @import("cone.zig");
const cub = @import("cube.zig");
const cyl = @import("cylinder.zig");
const mat = @import("matrix.zig");
const mtl = @import("material.zig");
const pln = @import("plane.zig");
const sph = @import("sphere.zig");

pub const CommonShapeAttributes = struct {
    transform: mat.Matrix = mat.identity,
    material: mtl.Material = mtl.Material{},
};

pub const Shape = union(enum) {
    cone: con.Cone,
    cube: cub.Cube,
    cylinder: cyl.Cylinder,
    plane: pln.Plane,
    sphere: sph.Sphere,
};
