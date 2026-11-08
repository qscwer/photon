#if !defined INCLUDE_SKY_CLOUDS_SAMPLING
#define INCLUDE_SKY_CLOUDS_SAMPLING

#if defined WORLD_OVERWORLD
#include "/include/sky/clouds/history.glsl"
#endif

// Sample filtered clouds
vec4 read_clouds_and_aurora(vec2 uv, out float apparent_distance) {
#if defined WORLD_OVERWORLD
    vec2 history_coord = clouds_history_texcoord(uv);
    apparent_distance = clouds_history_distance(history_coord);
    vec4 result = clouds_history_color(history_coord);

    if (LIGHTNING_FLASH_UNIFORM > 0.01) {
        float ambient_scattering = texture(colortex12, history_coord).z;
        result.xyz += LIGHTNING_FLASH_UNIFORM * lightning_flash_intensity
            * ambient_scattering;
    }

    result.xyz *= clamp01(1.0 - blindness - darknessFactor);

    return result;
#else
    return vec4(0.0, 0.0, 0.0, 1.0);
#endif
}

#endif // INCLUDE_SKY_CLOUDS_SAMPLING
