const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const background = rt.pln.Plane{
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(0, 0, 10), rt.mat.rotationX(std.math.pi / 2.0)),
            .material = .{
                .ambient = 0.8,
                .diffuse = 0.2,
                .specular = 0.0,
                .pattern = .{
                    .a = rt.cnv.Color{0.15, 0.15, 0.15},
                    .b = rt.cnv.Color{0.85, 0.85, 0.85},
                    .color_map = rt.pat.checker,
                },
            },
        },
    };

    const outer_sphere = rt.sph.Sphere{
        .common_attrs = .{
            .material = .{
                .color = rt.cnv.Color{1, 1, 1},
                .ambient = 0.0,
                .diffuse = 0.0,
                .specular = 0.9,
                .shininess = 300.0,
                .reflective = 0.9,
                .transparency = 0.9,
                .refractive_index = 1.5,
            },
        },
    };

    const inner_sphere = rt.sph.Sphere{
        .common_attrs = .{
            .transform = rt.mat.scaling(0.5, 0.5, 0.5),
            .material = .{
                .color = rt.cnv.Color{1, 1, 1},
                .ambient = 0.0,
                .diffuse = 0.0,
                .specular = 0.9,
                .shininess = 300.0,
                .reflective = 0.9,
                .transparency = 0.9,
                .refractive_index = 1.0003,
            },
        },
    };

    const world = rt.wrd.World{
        .allocator = allocator,
        .light = .{
            .intensity = rt.cnv.Color{0.9, 0.9, 0.9},
            .position = rt.tup.point(-2, 5, -10),
        },
        .planes = &.{ background },
        .spheres = &.{ outer_sphere, inner_sphere },
    };

    const image_width = 600;
    const image_height = 600;
    const field_of_view = 0.45;
    var camera = rt.cam.camera(image_width, image_height, field_of_view);

    const from = rt.tup.point(0, 0, -5);
    const to = rt.tup.point(0, 0, 0);
    const up = rt.tup.point(0, 1, 0);
    camera.transform = rt.trm.viewTransform(from, to, up);

    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    const file = try std.fs.cwd().createFile("mirror_room.ppm", .{});
    defer file.close();

    try canvas.toPPM(file.writer());
}
