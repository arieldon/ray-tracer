const std = @import("std");
const cnv = @import("canvas.zig");
const lht = @import("light.zig");
const pat = @import("pattern.zig");
const shp = @import("shape.zig");
const tup = @import("tuple.zig");

pub const Material = @This();

color: cnv.Color = cnv.Color{1, 1, 1},
pattern: ?pat.Pattern = null,

// Ambient reflection is background lighting.
ambient: f64 = 0.1,

// Diffuse reflection is light reflected from a matte surface.
diffuse: f64 = 0.9,

// Specular reflection is the reflection of the light source itself.
specular: f64 = 0.9,

// Parameter for size of specular highlight: the bright spot on curved surface.
shininess: f64 = 200.0,

// 0 defines a nonreflective material and 1 creates a perfect mirror.
reflective: f64 = 0.0,

// Determine degree light bends when entering or exiting this material. As
// this parameter increases, the angle at which light bends when it
// intersects this material also increases. The refractive index of a
// vacuum is 1. In physics, it is defined as the ratio between the speed of
// light in a vacuum (c) and the speed of light in the given material (v).
refractive_index: f64 = 1.0,

// Control the transparency of the material. 0 defines an opaque material
// and 1 defines a perfectly transparent material.
transparency: f64 = 0.0,

// Use the Phong reflection model.
pub fn lighting(
    shape_attrs: shp.CommonShapeAttributes,
    light: lht.PointLight,
    point: tup.Point,
    eye: tup.Vector,
    normal: tup.Vector,
    in_shadow: bool,
) cnv.Color {
    const material = shape_attrs.material;

    var color: cnv.Color = undefined;
    if (material.pattern != null) {
        color = material.pattern.?.atShape(shape_attrs, point);
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
        diffuse = cnv.Color{0, 0, 0};
        specular = cnv.Color{0, 0, 0};
    } else {
        diffuse = effective_color * @splat(3, material.diffuse) * @splat(3, cos_light_normal);

        const reflect = tup.reflect(-light_direction, normal);
        const cos_reflect_eye = tup.dot(reflect, eye);
        if (cos_reflect_eye <= 0) {
            // A negative value for the cosine of the angle between the
            // reflected vector and the eye vector implies the light reflects
            // away from the eye.
            specular = cnv.Color{0, 0, 0};
        } else {
            const factor = std.math.pow(f64, cos_reflect_eye, material.shininess);
            specular = light.intensity * @splat(3, material.specular) * @splat(3, factor);
        }
    }

    return ambient + diffuse + specular;
}
