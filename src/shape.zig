const std = @import("std");
const con = @import("cone.zig");
const cub = @import("cube.zig");
const cyl = @import("cylinder.zig");
const mat = @import("matrix.zig");
const mtl = @import("material.zig");
const pln = @import("plane.zig");
const sph = @import("sphere.zig");
const tri = @import("triangle.zig");

pub const Shape = union(enum) {
    sphere: sph.Sphere,
    plane: pln.Plane,
    cube: cub.Cube,
    cylinder: cyl.Cylinder,
    cone: con.Cone,
    triangle: tri.Triangle,
};

pub const CommonShapeAttributes = struct {
    transform: mat.Matrix = mat.identity,
    material: mtl.Material = mtl.Material{},
};
