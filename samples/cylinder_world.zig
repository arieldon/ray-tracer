const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Initialize a floor with a white and gray checker pattern.
    var floor = rt.pln.Plane{
        .common_attrs = .{
            .material = .{
                .ambient = 0.2,
                .diffuse = 0.9,
                .specular = 0.0,
                .pattern = .{
                    .a = rt.cnv.Color{0.5, 0.5, 0.5},
                    .b = rt.cnv.Color{0.75, 0.75, 0.75},
                    .color_map = rt.pat.checker,
                },
            },
        },
    };
    floor.common_attrs.material.pattern.?.transform = rt.mat.mul(
        rt.mat.rotationY(0.3), rt.mat.scaling(0.25, 0.25, 0.25));

    // Define the big, reflective cylinder slightly above and to the right of
    // the center of the scene.
    const big_cylinder = rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 0.75,
        .closed = true,
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(-1, 0, 1), rt.mat.scaling(0.5, 1, 0.5)),
            .material = .{
                .color = rt.cnv.Color{0, 0, 0.6},
                .diffuse = 0.1,
                .specular = 0.9,
                .shininess = 300.0,
                .reflective = 0.9,
            },
        },
    };

    // Cylinder a through d create a series of concentric cylinders together.
    const a = rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 0.2,
        .closed = false,
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(1, 0, 0), rt.mat.scaling(0.8, 1, 0.8)),
            .material = .{
                .color = rt.cnv.Color{1, 1, 0.3},
                .ambient = 0.1,
                .diffuse = 0.8,
                .specular = 0.9,
                .shininess = 300.0,
            },
        },
    };
    const b = rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 0.3,
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(1, 0, 0), rt.mat.scaling(0.6, 1, 0.6)),
            .material = .{
                .color = rt.cnv.Color{1, 0.9, 0.4},
                .ambient = 0.1,
                .diffuse = 0.8,
                .specular = 0.9,
                .shininess = 300.0,
            },
        },
    };
    const c = rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 0.4,
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(1, 0, 0), rt.mat.scaling(0.4, 1, 0.4)),
            .material = .{
                .color = rt.cnv.Color{1, 0.8, 0.5},
                .ambient = 0.1,
                .diffuse = 0.8,
                .specular = 0.9,
                .shininess = 300.0,
            },
        },
    };
    const d = rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 0.5,
        .closed = true,
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(1, 0, 0), rt.mat.scaling(0.2, 1, 0.2)),
            .material = .{
                .color = rt.cnv.Color{1, 0.7, 0.6},
                .ambient = 0.1,
                .diffuse = 0.8,
                .specular = 0.9,
                .shininess = 300.0,
            },
        },
    };

    // Define decorative cylinders.
    const w = rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 0.3,
        .closed = true,
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(0, 0, -0.75), rt.mat.scaling(0.05, 1, 0.05)),
            .material = .{
                .color = rt.cnv.Color{1, 0, 0},
                .ambient = 0.1,
                .diffuse = 0.9,
                .specular = 0.9,
                .shininess = 300.0,
            },
        },
    };
    const x = rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 0.3,
        .closed = true,
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.mul(rt.mat.translation(0, 0, -2.25), rt.mat.rotationY(-0.15)),
                rt.mat.mul(rt.mat.translation(0, 0, 1.5), rt.mat.scaling(0.05, 1, 0.05))),
            .material = .{
                .color = rt.cnv.Color{1, 1, 0},
                .ambient = 0.1,
                .diffuse = 0.9,
                .specular = 0.9,
                .shininess = 300.0,
            },
        },
    };
    const y = rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 0.3,
        .closed = true,
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.mul(rt.mat.translation(0, 0, -2.25), rt.mat.rotationY(-0.3)),
                rt.mat.mul(rt.mat.translation(0, 0, 1.5), rt.mat.scaling(0.05, 1, 0.05))),
            .material = .{
                .color = rt.cnv.Color{0, 1, 0},
                .ambient = 0.1,
                .diffuse = 0.9,
                .specular = 0.9,
                .shininess = 300.0,
            },
        },
    };
    const z = rt.cyl.Cylinder{
        .minimum = 0.0,
        .maximum = 0.3,
        .closed = true,
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.mul(rt.mat.translation(0, 0, -2.25), rt.mat.rotationY(-0.45)),
                rt.mat.mul(rt.mat.translation(0, 0, 1.5), rt.mat.scaling(0.05, 1, 0.05))),
            .material = .{
                .color = rt.cnv.Color{0, 1, 1},
                .ambient = 0.1,
                .diffuse = 0.9,
                .specular = 0.9,
                .shininess = 300.0,
            },
        },
    };

    // Initialize glass cylinder.
    const glass_cylinder = rt.cyl.Cylinder{
        .minimum = 0.0001,
        .maximum = 0.5,
        .closed = true,
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(0, 0, -1.5), rt.mat.scaling(0.33, 1, 0.33)),
            .material = .{
                .color = rt.cnv.Color{0.25, 0, 0},
                .diffuse = 0.1,
                .specular = 0.9,
                .shininess = 300.0,
                .reflective = 0.9,
                .transparency = 0.9,
                .refractive_index = 1.5,
            },
        },
    };

    var world = rt.wrd.World{
        .allocator = allocator,
        .light = .{
            .intensity = rt.cnv.Color{1, 1, 1},
            .position = rt.tup.point(1, 6.9, -4.9),
        },
        .planes = &.{ floor },
        .cylinders = &.{ big_cylinder, a, b, c, d, w, x, y, z, glass_cylinder },
    };

    const image_width = 800;
    const image_height = 400;
    const field_of_view = std.math.pi / 10.0;
    var camera = rt.cam.camera(image_width, image_height, field_of_view);

    const from = rt.tup.point(8, 3.5, -9);
    const to = rt.tup.point(0, 0.3, 0);
    const up = rt.tup.vector(0, 1, 0);
    camera.transform = rt.trm.viewTransform(from, to, up);

    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    const file = try std.fs.cwd().createFile("cylinder.ppm", .{});
    defer file.close();

    try canvas.toPPM(file.writer());
}
