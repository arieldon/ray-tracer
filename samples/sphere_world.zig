const std = @import("std");
const rt = @import("ray-tracer");

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    // Define constants for the properties of the image.
    const image_width = 1000;
    const image_height = 500;
    const field_of_view = std.math.pi / 3.0;

    // Create the floor using a large, flattened sphere.
    var floor = rt.sph.sphere();
    floor.shape.transform = rt.mat.scaling(10, 0.01, 10);
    floor.shape.material = rt.mtl.Material{
        .color = rt.cnv.color(1, 0.9, 0.9),
        .specular = 0,
    };

    // Create the wall on the left in a similar fashion to the floor, rotating
    // and translating it as well.
    var left_wall = rt.sph.sphere();
    left_wall.shape.transform = rt.mat.mul(
        rt.mat.mul(
            rt.mat.translation(0, 0, 5),
            rt.mat.mul(rt.mat.rotationY(-std.math.pi / 4.0), rt.mat.rotationX(std.math.pi / 2.0))),
        rt.mat.scaling(10, 0.01, 10));
    left_wall.shape.material = floor.shape.material;

    // Create the wall on the right.
    var right_wall = rt.sph.sphere();
    right_wall.shape.transform = rt.mat.mul(
        rt.mat.mul(
            rt.mat.translation(0, 0, 5),
            rt.mat.mul(rt.mat.rotationY(std.math.pi / 4.0), rt.mat.rotationX(std.math.pi / 2.0))),
        rt.mat.scaling(10, 0.01, 10));
    right_wall.shape.material = floor.shape.material;

    // Create the unit sphere slightly above the center of the scene.
    var middle = rt.sph.sphere();
    middle.shape.transform = rt.mat.translation(-0.5, 1, 0.5);
    middle.shape.material = rt.mtl.Material{
        .color = rt.cnv.color(0.1, 1, 0.5),
        .diffuse = 0.7,
        .specular = 0.3,
    };

    // Create the smaller sphere on the right.
    var right = rt.sph.sphere();
    right.shape.transform = rt.mat.mul(
        rt.mat.translation(1.5, 0.5, -0.5), rt.mat.scaling(0.5, 0.5, 0.5));
    right.shape.material = rt.mtl.Material{
        .color = rt.cnv.color(0.5, 1, 0.1),
        .diffuse = 0.7,
        .specular = 0.3,
    };

    // Create the smallest sphere in the scene on the left.
    var left = rt.sph.sphere();
    left.shape.transform = rt.mat.mul(
        rt.mat.translation(-1.5, 0.33, -0.75), rt.mat.scaling(0.33, 0.33, 0.33));
    left.shape.material = rt.mtl.Material{
        .color = rt.cnv.color(1, 0.8, 0.1),
        .diffuse = 0.7,
        .specular = 0.3,
    };

    // Allocate world.
    var world = rt.wrd.world(allocator);
    defer world.deinit();

    // Add floor and walls to the world.
    try world.spheres.append(floor);
    try world.spheres.append(left_wall);
    try world.spheres.append(right_wall);

    // Add spheres to the world.
    try world.spheres.append(middle);
    try world.spheres.append(right);
    try world.spheres.append(left);

    // Configure the world's light source.
    world.light = rt.lht.pointLight(rt.tup.point(-10, 10, -10), rt.cnv.color(1, 1, 1));

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
