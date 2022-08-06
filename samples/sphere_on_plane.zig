const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Define constants for the properties of the image.
    const image_width = 1024;
    const image_height = 1024;
    const field_of_view = std.math.pi / 4.0;

    // Use a plane for the floor.
    const floor = rt.pln.Plane{};

    // Use a plane for the backdrop.
    const backdrop = rt.pln.Plane{
        .common_attrs = .{
            .transform = rt.mat.mul(rt.mat.translation(0, 0, 3), rt.mat.rotationX(std.math.pi / 2.0)),
        },
    };

    // Place a sphere on the plane.
    const sphere = rt.sph.Sphere{
        .common_attrs = .{
            .transform = rt.mat.translation(0, 1, 0.5),
            .material = .{
                .color = rt.cnv.color(0.1, 0.75, 1),
                .diffuse = 0.7,
                .specular = 0.3,
            },
        },
    };

    // Allocate world to hold light source and items.
    const world = rt.wrd.World{
        .allocator = allocator,
        .light = .{
            .position = rt.tup.point(10, 10, -10),
            .intensity = rt.cnv.color(1, 1, 1)
        },
        .spheres = &.{ sphere },
        .planes = &.{ floor, backdrop },
    };

    // Create a camera to view and render the scene.
    var camera = rt.cam.camera(image_width, image_height, field_of_view);
    camera.transform = rt.trm.viewTransform(
        rt.tup.point(0, 1.5, -5), rt.tup.point(0, 1, 0), rt.tup.vector(0, 1, 0));

    // Render the scene onto a canvas.
    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    // Create a new file in the current working directory.
    const file = try std.fs.cwd().createFile("sphere_on_plane.ppm", .{});
    defer file.close();

    // Write contents of canvas as a viewable PPM file.
    try canvas.toPPM(file.writer());
}
