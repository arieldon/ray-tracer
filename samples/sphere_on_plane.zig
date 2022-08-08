const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Use a plane for the floor.
    const floor = rt.Plane{};

    // Use a plane for the backdrop.
    const backdrop = rt.Plane{
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(0, 0, 3), rt.mat.rotationX(std.math.pi / 2.0)),
        },
    };

    // Place a sphere on the plane.
    const sphere = rt.Sphere{
        .common_attrs = .{
            .transform = rt.mat.translation(0, 1, 0.5),
            .material = .{
                .color = rt.Color{0.1, 0.75, 1},
                .diffuse = 0.7,
                .specular = 0.3,
            },
        },
    };

    // Allocate world to hold light source and items.
    const world = rt.World{
        .allocator = allocator,
        .light = .{
            .position = rt.tup.point(10, 10, -10),
            .intensity = rt.Color{1, 1, 1},
        },
        .spheres = &.{ sphere },
        .planes = &.{ floor, backdrop },
    };

    // Create a camera to view and render the scene.
    const image_width = 1024;
    const image_height = 1024;
    const field_of_view = std.math.pi / 4.0;
    const from = rt.tup.point(0, 1.5, -5);
    const to = rt.tup.point(0, 1, 0);
    const up = rt.tup.point(0, 1, 0);
    var camera = rt.camera(image_width, image_height, field_of_view, from, to, up);

    // Render the scene onto a canvas.
    var canvas = try rt.render(allocator, camera, world);
    defer canvas.deinit();

    // Create a new file in the current working directory.
    const file = try std.fs.cwd().createFile("sphere_on_plane.ppm", .{});
    defer file.close();

    // Write contents of canvas as a viewable PPM file.
    try canvas.toPPM(file.writer());
}
