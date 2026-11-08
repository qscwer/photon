#if !defined INCLUDE_SKY_CLOUDS_HISTORY
#define INCLUDE_SKY_CLOUDS_HISTORY

vec2 clouds_history_texcoord(vec2 uv) {
    vec2 coord = uv * taau_render_scale;

#ifdef PHOTON_SR_ACTIVE
    // The cloud history uses unjittered rays. Match the SR scene sample and
    // leave room for the neighbouring texel read by textureGather.
    vec2 texel_size = rcp(view_res);
    vec2 render_size = floor(view_res * taau_render_scale);
    coord = clamp(
        coord - 0.5 * taa_offset,
        0.5 * texel_size,
        (render_size - 1.5) * texel_size
    );
#endif

    return coord;
}

float clouds_history_distance(vec2 texcoord) {
    return min_of(textureGather(colortex12, texcoord, 0));
}

vec4 clouds_history_color(vec2 texcoord) {
    float pixel_age
        = texelFetch(colortex12, ivec2(texcoord * view_res), 0).y;
    float lod = 2.0 * dampen(clamp01(1.0 - 0.1 * pixel_age));

#ifdef PHOTON_SR_ACTIVE
    // Newly exposed pixels use coarser mips. Keep their filter inside the
    // rendered rectangle even at the coarsest sampled level.
    vec2 mip_size = max(vec2(textureSize(colortex11, int(ceil(lod)))), 1.0);
    vec2 render_size = floor(view_res * taau_render_scale);
    vec2 mip_render_size = max(floor(render_size * mip_size / view_res), 1.0);
    texcoord = clamp(
        texcoord,
        0.5 / mip_size,
        (mip_render_size - 0.5) / mip_size
    );
#endif

    return textureLod(colortex11, texcoord, lod);
}

#endif // INCLUDE_SKY_CLOUDS_HISTORY
