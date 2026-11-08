/*
--------------------------------------------------------------------------------

  Photon Shader by SixthSurge

  program/c3_taau_prep:
  Prepare motion vectors for Super Resolution or neighborhood limits for TAAU

--------------------------------------------------------------------------------
*/

#include "/include/global.glsl"

#ifdef PHOTON_SR_ACTIVE

layout(location = 0) out vec2 motion_vectors;

/* RENDERTARGETS: 13 */

in vec2 uv;

uniform sampler2D depthtex0;
uniform mat4 gbufferModelView;
uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferProjection;
uniform mat4 gbufferProjectionInverse;
uniform mat4 gbufferPreviousModelView;
uniform mat4 gbufferPreviousProjection;
uniform vec3 cameraPosition;
uniform vec3 previousCameraPosition;
uniform float near;
uniform float far;
uniform vec2 view_res;
uniform vec2 taa_offset;

#if defined WORLD_OVERWORLD && !defined BLOCKY_CLOUDS
uniform sampler2D colortex11;
uniform sampler2D colortex12;
uniform float eyeAltitude;
uniform float frameTime;
uniform bool daylight_cycle_enabled;
#endif

#define TEMPORAL_REPROJECTION
#include "/include/utility/space_conversion.glsl"

#if defined WORLD_OVERWORLD && !defined BLOCKY_CLOUDS
#include "/include/sky/clouds/history.glsl"
#include "/include/sky/clouds/reprojection.glsl"
#endif

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(depthtex0, texel, 0).x;
    bool is_lod = false;

#ifdef LOD_MOD_ACTIVE
    float lod_depth = texelFetch(lod_depth_tex, texel, 0).x;
    is_lod = is_lod_terrain(depth, lod_depth);
    if (is_lod) {
        depth = lod_depth;
    }
#endif

    if (!is_lod && depth < hand_depth) {
        motion_vectors = vec2(0.0);
        return;
    }

    vec2 current_uv = uv - 0.5 * taa_offset / taau_render_scale;
    vec3 screen_pos = vec3(current_uv, min(depth, 1.0 - eps));
    vec3 scene_pos = view_to_scene_space(
        screen_to_view_space(screen_pos, false, is_lod)
    );

    // Sky pixels follow camera rotation without translation.
    vec2 previous_uv = reproject_scene_space(scene_pos, depth >= 1.0, is_lod).xy;
    vec2 velocity = previous_uv - current_uv;

#if defined WORLD_OVERWORLD && !defined BLOCKY_CLOUDS
    if (!is_lod && depth >= 1.0) {
        vec2 history_coord = clouds_history_texcoord(uv);
        float distance_to_cloud = clouds_history_distance(history_coord);

        if (distance_to_cloud > 0.0 && distance_to_cloud < 1e6 / CLOUDS_SCALE) {
            float cloud_weight = clamp01(
                1.0 - clouds_history_color(history_coord).a
            );
            vec2 cloud_uv = history_coord / taau_render_scale;
            vec2 cloud_velocity
                = reproject_clouds(cloud_uv, distance_to_cloud).xy - cloud_uv;
            velocity = mix(velocity, cloud_velocity, cloud_weight);
        }
    }
#endif

    motion_vectors = any(isnan(velocity)) || any(isinf(velocity))
        ? vec2(0.0)
        : clamp(velocity, vec2(-1.0), vec2(1.0));
}

#else

layout(location = 0) out vec3 min_color;
layout(location = 1) out vec3 max_color;

/* RENDERTARGETS: 1,2 */

in vec2 uv;

uniform sampler2D colortex0;

#include "/include/utility/color.glsl"

vec3 min_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return min(a, min(b, min(c, min(d, f))));
}

vec3 max_of(vec3 a, vec3 b, vec3 c, vec3 d, vec3 f) {
    return max(a, max(b, max(c, max(d, f))));
}

// Invertible tonemapping operator (Reinhard) applied before blending the
// current and previous frames Improves the appearance of emissive objects
vec3 reinhard(vec3 rgb) { return rgb / (rgb + 1.0); }

void main() {
    ivec2 texel = ivec2(gl_FragCoord.xy);

    // Fetch 3x3 neighborhood
    // a b c
    // d e f
    // g h i
    vec3 a = texelFetch(colortex0, texel + ivec2(-1, 1), 0).rgb;
    vec3 b = texelFetch(colortex0, texel + ivec2(0, 1), 0).rgb;
    vec3 c = texelFetch(colortex0, texel + ivec2(1, 1), 0).rgb;
    vec3 d = texelFetch(colortex0, texel + ivec2(-1, 0), 0).rgb;
    vec3 e = texelFetch(colortex0, texel, 0).rgb;
    vec3 f = texelFetch(colortex0, texel + ivec2(1, 0), 0).rgb;
    vec3 g = texelFetch(colortex0, texel + ivec2(-1, -1), 0).rgb;
    vec3 h = texelFetch(colortex0, texel + ivec2(0, -1), 0).rgb;
    vec3 i = texelFetch(colortex0, texel + ivec2(1, -1), 0).rgb;

    // Convert to YCoCg
    a = rgb_to_ycocg(reinhard(a));
    b = rgb_to_ycocg(reinhard(b));
    c = rgb_to_ycocg(reinhard(c));
    d = rgb_to_ycocg(reinhard(d));
    e = rgb_to_ycocg(reinhard(e));
    f = rgb_to_ycocg(reinhard(f));
    g = rgb_to_ycocg(reinhard(g));
    h = rgb_to_ycocg(reinhard(h));
    i = rgb_to_ycocg(reinhard(i));

    // Soft minimum and maximum ("Hybrid Reconstruction Antialiasing")
    //        b         a b c
    // (min d e f + min d e f) / 2
    //        h         g h i
    min_color = min_of(b, d, e, f, h);
    min_color += min_of(min_color, a, c, g, i);
    min_color *= 0.5;

    max_color = max_of(b, d, e, f, h);
    max_color += max_of(max_color, a, c, g, i);
    max_color *= 0.5;

    min_color = min_color * 0.5 + 0.5;
    max_color = max_color * 0.5 + 0.5;
}

#endif
//----------------------------------------------------------------------------//
