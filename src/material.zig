const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const lht = @import("light.zig");
const tup = @import("tuple.zig");

pub const Material = struct {
    color: cnv.Color,
    ambient: f32,   // Ambient reflection is background lighting.
    diffuse: f32,   // Diffuse reflection is light reflected from a matte surface.
    specular: f32,  // Specular reflection is the reflection of the light source itself.
    shininess: f32, // Parameter for size of specular highlight: the bright spot on curved surface.
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

// Use the Phong reflection model.
pub fn lighting(
        mtl: Material,
        light: lht.PointLight,
        point: tup.Point,
        eye: tup.Vector,
        normal: tup.Vector,
) cnv.Color {
    const effective_color = mtl.color * light.intensity;
    const light_direction = tup.normalize(light.position - point);

    // Compute the ambient contribution. In the Phong model, ambient
    // contribution is constant across the entire surface of the object.
    const ambient = effective_color * @splat(3, mtl.ambient);

    // Diffuse reflection depends on the angle between the light source and the
    // surface normal.
    var diffuse: cnv.Color = undefined;

    // Specular reflection depends on the angle between the reflection vector,
    // the eye vector, and the shininess parameter.
    var specular: cnv.Color = undefined;

    const cos_light_normal = tup.dot(light_direction, normal);
    if (cos_light_normal < 0) {
        // A negative value for the cosine of the angle between the light
        // vector and the surface normal vector implies the light is on the
        // other side of the surface.
        diffuse = cnv.color(0, 0, 0);
        specular = cnv.color(0, 0, 0);
    } else {
        diffuse = effective_color * @splat(3, mtl.diffuse) * @splat(3, cos_light_normal);

        const reflect = tup.reflect(-light_direction, normal);
        const cos_reflect_eye = tup.dot(reflect, eye);
        if (cos_reflect_eye <= 0) {
            // A negative value for the cosine of the angle between the
            // reflected vector and the eye vector implies the light reflects
            // away from the eye.
            specular = cnv.color(0, 0, 0);
        } else {
            const factor = std.math.pow(f32, cos_reflect_eye, mtl.shininess);
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
    const light = lht.pointLight(tup.point(0, 0, -10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expectEqual(result, cnv.color(1.9, 1.9, 1.9));
}

test "lighting with the eye between light and surface, eye offset 45 degrees" {
    const m = material();
    const position = tup.point(0, 0, 0);
    const a = @sqrt(2.0) / 2.0;
    const eyev = tup.vector(0, a, -a);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.pointLight(tup.point(0, 0, -10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expectEqual(result, cnv.color(1.0, 1.0, 1.0));
}

test "lighting with eye opposite surface, light offset 45 degrees" {
    const m = material();
    const position = tup.point(0, 0, 0);
    const eyev = tup.vector(0, 0, -1);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.pointLight(tup.point(0, 10, -10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expect(cnv.equal(result, cnv.color(0.7364, 0.7364, 0.7364)));
}

test "lighting with eye in the path of the reflection vector" {
    const m = material();
    const position = tup.point(0, 0, 0);
    const a = @sqrt(2.0) / 2.0;
    const eyev = tup.vector(0, -a, -a);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.pointLight(tup.point(0, 10, -10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expect(cnv.equal(result, cnv.color(1.6364, 1.6364, 1.6364)));
}

test "lighting with the light behind the surface" {
    const m = material();
    const position = tup.point(0, 0, 0);
    const eyev = tup.vector(0, 0, -1);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.pointLight(tup.point(0, 0, 10), cnv.color(1, 1, 1));
    const result = lighting(m, light, position, eyev, normalv);
    try expectEqual(result, cnv.color(0.1, 0.1, 0.1));
}
