#if !defined INCLUDE_SKY_CLOUDS_REPROJECTION
#define INCLUDE_SKY_CLOUDS_REPROJECTION

vec3 reproject_clouds(vec2 uv, float distance_to_cloud) {
    const float planet_radius = 6371e3;
    const float clouds_altocumulus_radius
        = planet_radius + CLOUDS_ALTOCUMULUS_ALTITUDE;
    const float clouds_cirrus_radius = planet_radius + CLOUDS_CIRRUS_ALTITUDE;
    const float clouds_cumulus_wind_angle = CLOUDS_CUMULUS_WIND_ANGLE * degree;
    const float clouds_altocumulus_wind_angle
        = CLOUDS_ALTOCUMULUS_WIND_ANGLE * degree;
    const float clouds_cirrus_wind_angle = CLOUDS_CIRRUS_WIND_ANGLE * degree;
    const vec3 clouds_cumulus_velocity = CLOUDS_CUMULUS_WIND_SPEED
        * vec3(cos(clouds_cumulus_wind_angle),
               0.0,
               sin(clouds_cumulus_wind_angle));
    const vec3 clouds_altocumulus_velocity = CLOUDS_ALTOCUMULUS_WIND_SPEED
        * vec3(cos(clouds_altocumulus_wind_angle),
               0.0,
               sin(clouds_altocumulus_wind_angle));
    const vec3 clouds_cirrus_velocity = CLOUDS_CIRRUS_WIND_SPEED
        * vec3(cos(clouds_cirrus_wind_angle),
               0.0,
               sin(clouds_cirrus_wind_angle));

    vec3 view_pos = screen_to_view_space(vec3(uv, 1.0), false, false);
    vec3 scene_pos = view_to_scene_space(view_pos);
    vec3 world_dir = normalize(scene_pos - gbufferModelViewInverse[3].xyz);

    vec3 cloud_pos
        = world_dir * distance_to_cloud + gbufferModelViewInverse[3].xyz;

    // Work out which layer this cloud belongs to
    vec3 velocity;
    vec3 air_cloud_pos
        = vec3(
              0.0,
              CLOUDS_SCALE * (eyeAltitude - SEA_LEVEL) + planet_radius,
              0.0
          )
        + CLOUDS_SCALE * cloud_pos;
    float r = length(air_cloud_pos);

    if (r < clouds_altocumulus_radius) {
        velocity = clouds_cumulus_velocity;
    } else if (r < clouds_cirrus_radius) {
        velocity = clouds_altocumulus_velocity;
    } else {
        velocity = clouds_cirrus_velocity;
    }

    cloud_pos += velocity * frameTime * rcp(CLOUDS_SCALE)
        * float(daylight_cycle_enabled);

    return reproject_scene_space(cloud_pos, false, false);
}

#endif // INCLUDE_SKY_CLOUDS_REPROJECTION
