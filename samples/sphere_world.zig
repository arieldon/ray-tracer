const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Define constants for the properties of the image.
    const image_width = 1000;
    const image_height = 500;
    const field_of_view = std.math.pi / 3.0;

    // Create the floor using a large, flattened sphere.
    const floor = rt.sph.Sphere{
        .common_attrs = .{
            .transform = rt.mat.scaling(10, 0.01, 10),
            .material = .{
                .color = rt.cnv.Color{1, 0.9, 0.9},
                .specular = 0,
            },
        }
    };

    // Create the wall on the left in a similar fashion to the floor, rotating
    // and translating it as well.
    const left_wall = rt.sph.Sphere{
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.mul(
                    rt.mat.translation(0, 0, 5),
                    rt.mat.rotationY(-std.math.pi / 4.0)),
                rt.mat.mul(
                    rt.mat.rotationX(std.math.pi / 2.0),
                    rt.mat.scaling(10, 0.01, 10))),
            .material = floor.common_attrs.material,
        },
    };

    // Create the wall on the right.
    const right_wall = rt.sph.Sphere{
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.mul(
                    rt.mat.translation(0, 0, 5),
                    rt.mat.rotationY(std.math.pi / 4.0)),
                rt.mat.mul(
                    rt.mat.rotationX(std.math.pi / 2.0),
                    rt.mat.scaling(10, 0.01, 10))),
            .material = floor.common_attrs.material,
        },
    };

    // Create the unit sphere slightly above the center of the scene.
    const middle = rt.sph.Sphere{
        .common_attrs = .{
            .transform = rt.mat.translation(-0.5, 1, 0.5),
            .material = .{
                .color = rt.cnv.Color{0.1, 1, 0.5},
                .diffuse = 0.7,
                .specular = 0.3,
            },
        },
    };

    // Create the smaller sphere on the right.
    const right = rt.sph.Sphere{
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.translation(1.5, 0.5, -0.5), rt.mat.scaling(0.5, 0.5, 0.5)),
            .material = .{
                .color = rt.cnv.Color{0.5, 1, 0.1},
                .diffuse = 0.7,
                .specular = 0.3,
            },
        },
    };

    // Create the smallest sphere in the scene on the left.
    const left = rt.sph.Sphere{
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.translation(-1.5, 0.33, -0.75), rt.mat.scaling(0.33, 0.33, 0.33)),
            .material = .{
                .color = rt.cnv.Color{1, 0.8, 0.1},
                .diffuse = 0.7,
                .specular = 0.3,
            },
        },
    };

    // Create world and assign spheres to it.
    const world = rt.wrd.World{
        .allocator = allocator,
        .light = .{
            .position = rt.tup.point(-10, 10, -10),
            .intensity = rt.cnv.color(1, 1, 1),
        },
        .spheres = &.{ floor, left_wall, right_wall, middle, right, left },
    };

    var camera = rt.cam.camera(image_width, image_height, field_of_view);
    camera.transform = rt.trm.viewTransform(
        rt.tup.point(0, 1.5, -5), rt.tup.point(0, 1, 0), rt.tup.vector(0, 1, 0));

    // Render the scene onto a canvas.
    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    // Create a new file in the current working directory.
    const file = try std.fs.cwd().createFile("sphere_world.ppm", .{});
    defer file.close();

    // Write contents of canvas as a viewable PPM file.
    try canvas.toPPM(file.writer());
}
