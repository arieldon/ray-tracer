const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;
const cnv = @import("canvas.zig");
const lht = @import("light.zig");
const pat = @import("pattern.zig");
const shp = @import("shape.zig");
const sph = @import("sphere.zig");
const tup = @import("tuple.zig");

pub const Material = struct {
    color: cnv.Color = cnv.color(1, 1, 1),
    pattern: ?pat.Pattern = null,

    // Ambient reflection is background lighting.
    ambient: f32 = 0.1,

    // Diffuse reflection is light reflected from a matte surface.
    diffuse: f32 = 0.9,

    // Specular reflection is the reflection of the light source itself.
    specular: f32 = 0.9,

    // Parameter for size of specular highlight: the bright spot on curved surface.
    shininess: f32 = 200.0,

    // 0 defines a nonreflective material and 1 creates a perfect mirror.
    reflective: f32 = 0.0,

    // Determine degree light bends when entering or exiting this material. As
    // this parameter increases, the angle at which light bends when it
    // intersects this material also increases. The refractive index of a
    // vacuum is 1.
    refractive_index: f32 = 1.0,

    // Control the transparency of the material. 0 defines an opaque material
    // and 1 defines a perfectly transparent material.
    transparency: f32 = 0.0,
};

// Use the Phong reflection model.
pub fn lighting(
        shape: shp.Shape,
        light: lht.PointLight,
        point: tup.Point,
        eye: tup.Vector,
        normal: tup.Vector,
        in_shadow: bool,
) cnv.Color {
    const material = shape.material;

    var color: cnv.Color = undefined;
    if (material.pattern != null) {
        color = material.pattern.?.atShape(shape, point);
    } else {
        color = material.color;
    }

    const effective_color = color * light.intensity;
    const light_direction = tup.normalize(light.position - point);

    // Compute the ambient contribution. In the Phong model, ambient
    // contribution is constant across the entire surface of the object.
    const ambient = effective_color * @splat(3, material.ambient);

    // If the point falls under a shadow, the Phong reflection models ignores
    // the contributions of diffuse and specular lighting because both depend
    // on the light source, and the light source doesn't contribute to points
    // engulfed in a shadow.
    if (in_shadow) return ambient;

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
        diffuse = effective_color * @splat(3, material.diffuse) * @splat(3, cos_light_normal);

        const reflect = tup.reflect(-light_direction, normal);
        const cos_reflect_eye = tup.dot(reflect, eye);
        if (cos_reflect_eye <= 0) {
            // A negative value for the cosine of the angle between the
            // reflected vector and the eye vector implies the light reflects
            // away from the eye.
            specular = cnv.color(0, 0, 0);
        } else {
            const factor = std.math.pow(f32, cos_reflect_eye, material.shininess);
            specular = light.intensity * @splat(3, material.specular) * @splat(3, factor);
        }
    }

    return ambient + diffuse + specular;
}

test "the default material" {
    const m = Material{};
    try expectEqual(m.color, cnv.color(1, 1, 1));
    try expectEqual(m.ambient, 0.1);
    try expectEqual(m.diffuse, 0.9);
    try expectEqual(m.specular, 0.9);
    try expectEqual(m.shininess, 200.0);
}

test "lighting with the eye between the light and the surface" {
    const sphere = sph.Sphere{};
    const position = tup.point(0, 0, 0);
    const eyev = tup.vector(0, 0, -1);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.PointLight{
        .position = tup.point(0, 0, -10),
        .intensity = cnv.Color{1, 1, 1},
    };
    const in_shadow = false;
    const result = lighting(sphere.shape, light, position, eyev, normalv, in_shadow);
    try expectEqual(result, cnv.color(1.9, 1.9, 1.9));
}

test "lighting with the eye between light and surface, eye offset 45 degrees" {
    const sphere = sph.Sphere{};
    const position = tup.point(0, 0, 0);
    const a = @sqrt(2.0) / 2.0;
    const eyev = tup.vector(0, a, -a);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.PointLight{
        .position = tup.point(0, 0, -10),
        .intensity = cnv.Color{1, 1, 1},
    };
    const in_shadow = false;
    const result = lighting(sphere.shape, light, position, eyev, normalv, in_shadow);
    try expectEqual(result, cnv.color(1.0, 1.0, 1.0));
}

test "lighting with eye opposite surface, light offset 45 degrees" {
    const sphere = sph.Sphere{};
    const position = tup.point(0, 0, 0);
    const eyev = tup.vector(0, 0, -1);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.PointLight{
        .position = tup.point(0, 10, -10),
        .intensity = cnv.Color{1, 1, 1},
    };
    const in_shadow = false;
    const result = lighting(sphere.shape, light, position, eyev, normalv, in_shadow);
    try expect(cnv.equal(result, cnv.color(0.7364, 0.7364, 0.7364)));
}

test "lighting with eye in the path of the reflection vector" {
    const sphere = sph.Sphere{};
    const position = tup.point(0, 0, 0);
    const a = @sqrt(2.0) / 2.0;
    const eyev = tup.vector(0, -a, -a);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.PointLight{
        .position = tup.point(0, 10, -10),
        .intensity = cnv.Color{1, 1, 1},
    };
    const in_shadow = false;
    const result = lighting(sphere.shape, light, position, eyev, normalv, in_shadow);
    try expect(cnv.equal(result, cnv.color(1.6364, 1.6364, 1.6364)));
}

test "lighting with the light behind the surface" {
    const sphere = sph.Sphere{};
    const position = tup.point(0, 0, 0);
    const eyev = tup.vector(0, 0, -1);
    const normalv = tup.vector(0, 0, -1);
    const light = lht.PointLight{
        .position = tup.point(0, 0, 10),
        .intensity = cnv.Color{1, 1, 1},
    };
    const in_shadow = false;
    const result = lighting(sphere.shape, light, position, eyev, normalv, in_shadow);
    try expectEqual(result, cnv.color(0.1, 0.1, 0.1));
}

test "lighting with the surface in a shadow" {
    const sphere = sph.Sphere{};
    const position = tup.point(0, 0, 0);
    const eye = tup.vector(0, 0, -1);
    const normal = tup.vector(0, 0, -1);
    const light = lht.PointLight{
        .position = tup.point(0, 0, -10),
        .intensity = cnv.Color{1, 1, 1},
    };
    const in_shadow = true;
    const result = lighting(sphere.shape, light, position, eye, normal, in_shadow);
    try expectEqual(result, cnv.color(0.1, 0.1, 0.1));
}

test "lighting with a pattern applied" {
    const white = cnv.Color{1, 1, 1};
    const black = cnv.Color{0, 0, 0};
    const sphere = sph.Sphere{
        .shape = .{
            .shape_type = .sphere,
            .material = .{
                .pattern = pat.Pattern{
                    .a = white,
                    .b = black,
                    .color_map = pat.stripe,
                },
                .ambient = 1,
                .diffuse = 0,
                .specular = 0,
            },
        },
    };
    const eye = tup.vector(0, 0, -1);
    const normal = tup.vector(0, 0, -1);
    const light = lht.PointLight{
        .position = tup.point(0, 0, -10),
        .intensity = cnv.Color{1, 1, 1},
    };

    const c1 = lighting(sphere.shape, light, tup.point(0.9, 0, 0), eye, normal, false);
    const c2 = lighting(sphere.shape, light, tup.point(1.1, 0, 0), eye, normal, false);
    try expectEqual(c1, cnv.color(1, 1, 1));
    try expectEqual(c2, cnv.color(0, 0, 0));
}
