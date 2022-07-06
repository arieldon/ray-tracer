const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Define image properties.
    const image_width = 1024;
    const image_height = 1024;
    const field_of_view = std.math.pi / 2.0;

    const blue = rt.cnv.Color{0.05, 0.25, 1};
    const orange = rt.cnv.Color{1, 0.5, 0.25};

    // Create the floor.
    const pattern = rt.pat.Pattern{
        .a = orange,
        .b = blue,
        .color_map = rt.pat.stripe,
    };
    const floor = rt.pln.Plane{
        .shape = rt.shp.Shape{
            .shape_type = .plane,
            .material = .{ .pattern = pattern },
        },
    };

    // Create a sphere with blue and orange stripes.
    const rotated_pattern = rt.pat.Pattern{
        .a = blue,
        .b = orange,
        .transform = rt.mat.rotationZ(-std.math.pi / 4.0),
        .color_map = rt.pat.stripe,
    };
    const sphere = rt.sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .material = .{ .pattern = rotated_pattern },
            .transform = rt.mat.translation(0, 1, 0),
        },
    };

    // Allocate world to hold light sources and items.
    var world = rt.wrd.world(allocator);
    defer world.deinit();

    // Define light source in the world.
    world.light = rt.lht.pointLight(rt.tup.point(0, 10, -10), rt.cnv.color(1, 1, 1));

    // Add items to the world to render them.
    try world.spheres.append(sphere);
    try world.planes.append(floor);

    // Create a camera to view and render the scene.
    var camera = rt.cam.camera(image_width, image_height, field_of_view);
    camera.transform = rt.trm.viewTransform(
        rt.tup.point(0, 1.5, -5), rt.tup.point(0, 1, 0), rt.tup.vector(0, 1, 0));

    // Render the scene onto a canvas.
    var canvas = try rt.cam.render(allocator, camera, world);
    defer canvas.deinit();

    // Create a new file in the current working directory.
    const file = try std.fs.cwd().createFile("striped_scene.ppm", .{});
    defer file.close();

    // Write contents of canvas as a viewable PPM file.
    try canvas.toPPM(file.writer());
}
