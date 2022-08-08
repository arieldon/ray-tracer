const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    const blue = rt.Color{0.05, 0.25, 1};
    const orange = rt.Color{1, 0.5, 0.25};

    // Create the floor.
    const pattern = rt.Pattern{
        .a = orange,
        .b = blue,
        .color_map = rt.stripe,
    };
    const floor = rt.Plane{
        .common_attrs = .{
            .material = .{ .pattern = pattern },
        },
    };

    // Create a sphere with blue and orange stripes.
    const rotated_pattern = rt.Pattern{
        .a = blue,
        .b = orange,
        .transform = rt.mat.rotationZ(-std.math.pi / 4.0),
        .color_map = rt.stripe,
    };
    const sphere = rt.Sphere{
        .common_attrs = .{
            .material = .{ .pattern = rotated_pattern },
            .transform = rt.mat.translation(0, 1, 0),
        },
    };

    // Allocate world to hold light sources and items.
    const world = rt.World{
        .allocator = allocator,
        .light = .{
            .position = rt.tup.point(0, 10, -10),
            .intensity = rt.Color{1, 1, 1},
        },
        .spheres = &.{ sphere },
        .planes = &.{ floor },
    };

    // Create a camera to view and render the scene.
    const image_width = 1024;
    const image_height = 1024;
    const field_of_view = std.math.pi / 2.0;
    const from = rt.tup.point(0, 1.5, -5);
    const to = rt.tup.point(0, 1, 0);
    const up = rt.tup.point(0, 1, 0);
    var camera = rt.camera(image_width, image_height, field_of_view, from, to, up);

    // Render the scene onto a canvas.
    var canvas = try rt.render(allocator, camera, world);
    defer canvas.deinit();

    // Create a new file in the current working directory.
    const file = try std.fs.cwd().createFile("striped_scene.ppm", .{});
    defer file.close();

    // Write contents of canvas as a viewable PPM file.
    try canvas.toPPM(file.writer());
}
