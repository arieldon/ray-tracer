const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const lht = @import("light.zig");
const tup = @import("tuple.zig");

pub const Material = struct {
    color: cnv.Color,
    ambient: f32,
    diffuse: f32,
    specular: f32,
    shininess: f32,
};

pub fn material() Material {
    return .{
        .color = cnv.color(1, 1, 1),
        .ambient = 0.1,
        .diffuse = 0.9,
        .specular = 0.9,
        .shininess = 200.0,
    };
}

pub fn lighting(
        mtl: Material, light: lht.PointLight,
        point: tup.Point, eyev: tup.Vector, normalv: tup.Vector
) cnv.Color {
    // Combine the surface color with intensity and color of light.
    const effective_color = mtl.color * light.intensity;

    // Calculate direction to light source.
    const lightv = tup.normalize(light.position - point);

    // Compute the ambient contribution.
    const ambient = effective_color * @splat(3, mtl.ambient);

    var diffuse: cnv.Color = undefined;
    var specular: cnv.Color = undefined;

    const light_dot_normal = tup.dot(lightv, normalv);
    if (light_dot_normal < 0) {
        diffuse = cnv.color(0, 0, 0);
        specular = cnv.color(0, 0, 0);
    } else {
        diffuse = effective_color * @splat(3, mtl.diffuse) * @splat(3, light_dot_normal);

        const reflectv = tup.reflect(-lightv, normalv);
        const reflect_dot_eye = tup.dot(reflectv, eyev);
        if (reflect_dot_eye <= 0) {
            specular = cnv.color(0, 0, 0);
        } else {
            const factor = std.math.pow(f32, reflect_dot_eye, mtl.shininess);
            specular = light.intensity * @splat(3, mtl.specular) * @splat(3, factor);
        }
    }

    return ambient + diffuse + specular;
}

test "the default material" {
    const m = material();
    try expectEqual(m.color, cnv.color(1, 1, 1));
    try expectEqual(m.ambient, 0.1);
    try expectEqual(m.diffuse, 0.9);
    try expectEqual(m.specular, 0.9);
    try expectEqual(m.shininess, 200.0);
}

test "lighting with the eye between the light and the surface" {
    const m = material();
    const position = tup.point(0, 0, 0);
    const eyev = tup.vector(0, 0, -1);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.point_light(tup.point(0, 0, -10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expectEqual(result, cnv.color(1.9, 1.9, 1.9));
}

test "lighting with the eye between light and surface, eye offset 45 degrees" {
    const m = material();
    const position = tup.point(0, 0, 0);
    const a = @sqrt(2.0) / 2.0;
    const eyev = tup.vector(0, a, -a);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.point_light(tup.point(0, 0, -10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expectEqual(result, cnv.color(1.0, 1.0, 1.0));
}

test "lighting with eye opposite surface, light offset 45 degrees" {
    const m = material();
    const position = tup.point(0, 0, 0);
    const eyev = tup.vector(0, 0, -1);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.point_light(tup.point(0, 10, -10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expect(cnv.equal(result, cnv.color(0.7364, 0.7364, 0.7364)));
}

test "lighting with eye in the path of the reflection vector" {
    const m = material();
    const position = tup.point(0, 0, 0);
    const a = @sqrt(2.0) / 2.0;
    const eyev = tup.vector(0, -a, -a);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.point_light(tup.point(0, 10, -10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expect(cnv.equal(result, cnv.color(1.6364, 1.6364, 1.6364)));
}

test "lighting with the light behind the surface" {
    const m = material();
    const position = tup.point(0, 0, 0);
    const eyev = tup.vector(0, 0, -1);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.point_light(tup.point(0, 0, 10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expectEqual(result, cnv.color(0.1, 0.1, 0.1));
}
