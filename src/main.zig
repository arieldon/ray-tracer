const std = @import("std");

pub const mat = @import("matrix.zig");
pub const obj = @import("obj_file.zig");
pub const trm = @import("transformation.zig");
pub const tup = @import("tuple.zig");

pub usingnamespace @import("camera.zig");
pub usingnamespace @import("canvas.zig");
pub usingnamespace @import("cone.zig");
pub usingnamespace @import("cube.zig");
pub usingnamespace @import("cylinder.zig");
pub usingnamespace @import("group.zig");
pub usingnamespace @import("material.zig");
pub usingnamespace @import("pattern.zig");
pub usingnamespace @import("plane.zig");
pub usingnamespace @import("ray.zig");
pub usingnamespace @import("sphere.zig");
pub usingnamespace @import("triangle.zig");
pub usingnamespace @import("world.zig");
