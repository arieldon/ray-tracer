const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Create the floor using a large, flattened sphere.
    const floor = rt.Sphere{
        .common_attrs = .{
            .transform = rt.mat.scaling(10, 0.01, 10),
            .material = .{
                .color = rt.Color{1, 0.9, 0.9},
                .specular = 0,
            },
        }
    };

    // Create the wall on the left in a similar fashion to the floor, rotating
    // and translating it as well.
    const left_wall = rt.Sphere{
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
    const right_wall = rt.Sphere{
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
    const middle = rt.Sphere{
        .common_attrs = .{
            .transform = rt.mat.translation(-0.5, 1, 0.5),
            .material = .{
                .color = rt.Color{0.1, 1, 0.5},
                .diffuse = 0.7,
                .specular = 0.3,
            },
        },
    };

    // Create the smaller sphere on the right.
    const right = rt.Sphere{
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.translation(1.5, 0.5, -0.5), rt.mat.scaling(0.5, 0.5, 0.5)),
            .material = .{
                .color = rt.Color{0.5, 1, 0.1},
                .diffuse = 0.7,
                .specular = 0.3,
            },
        },
    };

    // Create the smallest sphere in the scene on the left.
    const left = rt.Sphere{
        .common_attrs = .{
            .transform = rt.mat.mul(
                rt.mat.translation(-1.5, 0.33, -0.75), rt.mat.scaling(0.33, 0.33, 0.33)),
            .material = .{
                .color = rt.Color{1, 0.8, 0.1},
                .diffuse = 0.7,
                .specular = 0.3,
            },
        },
    };

    // Create world and assign spheres to it.
    const world = rt.World{
        .allocator = allocator,
        .light = .{
            .position = rt.tup.point(-10, 10, -10),
            .intensity = rt.Color{1, 1, 1},
        },
        .spheres = &.{ floor, left_wall, right_wall, middle, right, left },
    };

    // Define constants for the properties of the image.
    const image_width = 1000;
    const image_height = 500;
    const field_of_view = std.math.pi / 3.0;
    const from = rt.tup.point(0, 1.5, -5);
    const to = rt.tup.point(0, 1, 0);
    const up = rt.tup.point(0, 1, 0);
    var camera = rt.camera(image_width, image_height, field_of_view, from, to, up);

    // Render the scene onto a canvas.
    var canvas = try rt.render(allocator, camera, world);
    defer canvas.deinit();

    // Create a new file in the current working directory.
    const file = try std.fs.cwd().createFile("sphere_world.ppm", .{});
    defer file.close();

    // Write contents of canvas as a viewable PPM file.
    try canvas.toPPM(file.writer());
}
