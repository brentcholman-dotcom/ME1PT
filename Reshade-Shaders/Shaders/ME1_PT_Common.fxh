/*==============================================================================
    ME1 Path Tracing - Common Utilities

    Common functions and utilities shared across all path tracing modules.
    Optimized for Mass Effect 1 Legendary Edition (Unreal Engine 3, DX11)

    Features:
    - Depth buffer reconstruction and linearization
    - Normal reconstruction from depth
    - View/world space transformations
    - Temporal reprojection helpers
    - Blue noise sampling
    - Material property estimation
==============================================================================*/

#pragma once

//==============================================================================
// Constants and Defines
//==============================================================================

#define PI 3.14159265359
#define TWO_PI 6.28318530718
#define HALF_PI 1.57079632679
#define INV_PI 0.31830988618
#define GOLDEN_RATIO 1.61803398875
#define EPSILON 0.0001

// UE3 typical depth buffer configuration
#define DEPTH_NEAR_PLANE 1.0
#define DEPTH_FAR_PLANE 100000.0

//==============================================================================
// External Uniforms (provided by ReShade)
//==============================================================================

uniform float frametime < source = "frametime"; >;
uniform int framecount < source = "framecount"; >;
uniform float2 pixelsize < source = "pixelsize"; >;
uniform float2 screensize < source = "screensize"; >;

//==============================================================================
// Depth Buffer Access
//==============================================================================

/**
 * Sample the depth buffer at given texture coordinates
 * Returns non-linear depth value [0,1]
 */
float SampleDepth(float2 texcoord)
{
    return ReShade::GetLinearizedDepth(texcoord);
}

/**
 * Sample depth buffer using explicit LOD (safe for use in loops)
 * This avoids gradient instruction issues in dynamic loops
 */
float SampleDepthLod(float2 texcoord)
{
    #if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
        texcoord.y = 1.0 - texcoord.y;
    #endif
    float depth = tex2Dlod(ReShade::DepthBuffer, float4(texcoord, 0, 0)).x;
    #if RESHADE_DEPTH_INPUT_IS_REVERSED
        depth = 1.0 - depth;
    #endif
    #if RESHADE_DEPTH_INPUT_IS_LOGARITHMIC
        const float C = 0.01;
        depth = (exp(depth * log(C + 1.0)) - 1.0) / C;
    #endif
    depth /= RESHADE_DEPTH_LINEARIZATION_FAR_PLANE - depth * RESHADE_DEPTH_LINEARIZATION_FAR_PLANE + depth;
    return depth;
}

/**
 * Linearize depth value from [0,1] to view-space depth in world units
 * Optimized for UE3's typical depth buffer configuration
 */
float LinearizeDepth(float depth)
{
    // Convert from [0,1] to actual depth in world units
    // ReShade's GetLinearizedDepth already does most of the work
    // This scales it to approximate world units for Mass Effect
    return depth * DEPTH_FAR_PLANE;
}

/**
 * Convert depth to view-space Z coordinate
 */
float DepthToViewZ(float depth)
{
    return LinearizeDepth(depth);
}

/**
 * Check if depth value represents sky/background
 */
bool IsSky(float depth)
{
    return depth > 0.9999;
}

//==============================================================================
// Position Reconstruction
//==============================================================================

/**
 * Reconstruct view-space position from texture coordinates and depth
 */
float3 GetViewPosition(float2 texcoord, float depth)
{
    // Convert texcoord to NDC space [-1,1]
    float2 ndc = texcoord * 2.0 - 1.0;

    #if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
        ndc.y = -ndc.y;
    #endif

    // Reconstruct view-space position
    // Assuming standard perspective projection
    float viewZ = DepthToViewZ(depth);
    float aspect = BUFFER_WIDTH / float(BUFFER_HEIGHT);
    float fov = 75.0; // Typical ME1 FOV, adjustable if needed
    float tanHalfFov = tan(radians(fov) * 0.5);

    float3 viewPos;
    viewPos.z = -viewZ;
    viewPos.x = ndc.x * viewZ * tanHalfFov * aspect;
    viewPos.y = ndc.y * viewZ * tanHalfFov;

    return viewPos;
}

/**
 * Reconstruct world-space position (approximate, without camera matrix)
 */
float3 GetWorldPosition(float2 texcoord, float depth)
{
    // For screen-space techniques, view space is often sufficient
    // This is a simplified world position estimation
    return GetViewPosition(texcoord, depth);
}

//==============================================================================
// Normal Reconstruction
//==============================================================================

/**
 * Reconstruct view-space normal from depth buffer using derivatives
 * High quality method using cross product of depth gradients
 */
float3 ReconstructNormal(float2 texcoord)
{
    float depth = SampleDepth(texcoord);

    if (IsSky(depth))
        return float3(0, 0, 1);

    // Sample neighbor depths for gradient calculation
    float depthL = SampleDepth(texcoord + float2(-pixelsize.x, 0));
    float depthR = SampleDepth(texcoord + float2(pixelsize.x, 0));
    float depthU = SampleDepth(texcoord + float2(0, -pixelsize.y));
    float depthD = SampleDepth(texcoord + float2(0, pixelsize.y));

    // Reconstruct positions
    float3 posC = GetViewPosition(texcoord, depth);
    float3 posL = GetViewPosition(texcoord + float2(-pixelsize.x, 0), depthL);
    float3 posR = GetViewPosition(texcoord + float2(pixelsize.x, 0), depthR);
    float3 posU = GetViewPosition(texcoord + float2(0, -pixelsize.y), depthU);
    float3 posD = GetViewPosition(texcoord + float2(0, pixelsize.y), depthD);

    // Calculate tangent vectors
    float3 dx = (abs(depthR - depth) < abs(depthL - depth)) ? posR - posC : posC - posL;
    float3 dy = (abs(depthD - depth) < abs(depthU - depth)) ? posD - posC : posC - posU;

    // Cross product to get normal
    float3 normal = normalize(cross(dy, dx));

    return normal;
}

/**
 * LOD version of ReconstructNormal (safe for use in loops)
 */
float3 ReconstructNormalLod(float2 texcoord)
{
    float depth = SampleDepthLod(texcoord);

    if (IsSky(depth))
        return float3(0, 0, 1);

    // Sample neighbor depths for gradient calculation
    float depthL = SampleDepthLod(texcoord + float2(-pixelsize.x, 0));
    float depthR = SampleDepthLod(texcoord + float2(pixelsize.x, 0));
    float depthU = SampleDepthLod(texcoord + float2(0, -pixelsize.y));
    float depthD = SampleDepthLod(texcoord + float2(0, pixelsize.y));

    // Reconstruct positions
    float3 posC = GetViewPosition(texcoord, depth);
    float3 posL = GetViewPosition(texcoord + float2(-pixelsize.x, 0), depthL);
    float3 posR = GetViewPosition(texcoord + float2(pixelsize.x, 0), depthR);
    float3 posU = GetViewPosition(texcoord + float2(0, -pixelsize.y), depthU);
    float3 posD = GetViewPosition(texcoord + float2(0, pixelsize.y), depthD);

    // Calculate tangent vectors
    float3 dx = (abs(depthR - depth) < abs(depthL - depth)) ? posR - posC : posC - posL;
    float3 dy = (abs(depthD - depth) < abs(depthU - depth)) ? posD - posC : posC - posU;

    // Cross product to get normal
    float3 normal = normalize(cross(dy, dx));

    return normal;
}

/**
 * Improved normal reconstruction with better edge handling
 */
float3 ReconstructNormalImproved(float2 texcoord)
{
    float depth = SampleDepth(texcoord);

    if (IsSky(depth))
        return float3(0, 0, 1);

    // Use a 3x3 kernel for more robust normal estimation
    float3 posC = GetViewPosition(texcoord, depth);

    // Sample 4 diagonal neighbors
    float2 offsets[4] = {
        float2(-pixelsize.x, -pixelsize.y),
        float2(pixelsize.x, -pixelsize.y),
        float2(-pixelsize.x, pixelsize.y),
        float2(pixelsize.x, pixelsize.y)
    };

    float3 normal = float3(0, 0, 0);
    int validSamples = 0;

    [loop]
    for (int i = 0; i < 4; i++)
    {
        float2 uv1 = texcoord + offsets[i];
        float2 uv2 = texcoord + offsets[(uint(i) + 1u) & 3u];

        float depth1 = SampleDepth(uv1);
        float depth2 = SampleDepth(uv2);

        // Skip if depth discontinuity is too large (edge case)
        if (abs(depth1 - depth) > 0.1 || abs(depth2 - depth) > 0.1)
            continue;

        float3 pos1 = GetViewPosition(uv1, depth1);
        float3 pos2 = GetViewPosition(uv2, depth2);

        float3 v1 = pos1 - posC;
        float3 v2 = pos2 - posC;

        normal += cross(v2, v1);
        validSamples++;
    }

    if (validSamples > 0)
        normal /= float(validSamples);
    else
        return float3(0, 0, 1); // Fallback

    return normalize(normal);
}

//==============================================================================
// Temporal Reprojection
//==============================================================================

/**
 * Estimate motion vector by comparing current and previous frame depth
 * Simple but effective for stationary camera with moving objects
 */
float2 EstimateMotionVector(float2 texcoord, float currentDepth, sampler2D previousDepthTex)
{
    // Search in a small window for matching depth
    float bestMatch = 1e10;
    float2 bestOffset = float2(0, 0);

    const int searchRadius = 5; // v1.1.1: Increased from 2 to 5 for better flat surface tracking

    [loop]
    for (int y = -searchRadius; y <= searchRadius; y++)
    {
        [loop]
        for (int x = -searchRadius; x <= searchRadius; x++)
        {
            float2 offset = float2(x, y) * pixelsize;
            float2 sampleUV = texcoord + offset;

            if (any(sampleUV < 0) || any(sampleUV > 1))
                continue;

            float prevDepth = tex2Dlod(previousDepthTex, float4(sampleUV, 0, 0)).r;
            float depthDiff = abs(prevDepth - currentDepth);

            if (depthDiff < bestMatch)
            {
                bestMatch = depthDiff;
                bestOffset = -offset; // Negative because we're finding where it came from
            }
        }
    }

    // Only return motion vector if we found a good match
    // v1.1.1: Tightened from 0.05 to 0.01 for more precise matching
    return (bestMatch < 0.01) ? bestOffset : float2(0, 0);
}

/**
 * Check if reprojected sample is valid (disocclusion detection)
 */
bool IsReprojectionValid(float2 prevUV, float currentDepth, float previousDepth)
{
    // Check bounds
    if (any(prevUV < 0) || any(prevUV > 1))
        return false;

    // Check depth similarity (disocclusion test)
    float depthDiff = abs(currentDepth - previousDepth);
    // v1.1.1: Tightened from 0.1 to 0.02 to catch subtle mismatches on flat surfaces
    if (depthDiff > 0.02) // Threshold for disocclusion
        return false;

    return true;
}

//==============================================================================
// Blue Noise Sampling
//==============================================================================

// Blue noise texture (will be loaded from file)
texture2D BlueNoiseTex < source = "BlueNoise_256x256.png"; >
{
    Width = 256;
    Height = 256;
    Format = RGBA8;
};
sampler2D BlueNoise
{
    Texture = BlueNoiseTex;
    AddressU = REPEAT;
    AddressV = REPEAT;
    MagFilter = POINT;
    MinFilter = POINT;
};

/**
 * Sample blue noise texture with temporal dithering
 */
float4 SampleBlueNoise(float2 texcoord)
{
    // Tile the blue noise and add temporal offset
    float2 noiseUV = texcoord * (screensize / 256.0);

    // Add temporal rotation for better temporal distribution
    float angle = float(framecount & 63u) * GOLDEN_RATIO * TWO_PI;
    float2 offset = float2(cos(angle), sin(angle)) * 0.001;

    return tex2D(BlueNoise, noiseUV + offset);
}

/**
 * Sample blue noise texture using explicit LOD (safe for loops)
 */
float4 SampleBlueNoiseLod(float2 texcoord)
{
    // Tile the blue noise and add temporal offset
    float2 noiseUV = texcoord * (screensize / 256.0);

    // Add temporal rotation for better temporal distribution
    float angle = float(framecount & 63u) * GOLDEN_RATIO * TWO_PI;
    float2 offset = float2(cos(angle), sin(angle)) * 0.001;

    return tex2Dlod(BlueNoise, float4(noiseUV + offset, 0, 0));
}

/**
 * Get a random offset using blue noise (for ray sampling)
 */
float2 GetBlueNoiseOffset(float2 texcoord, int sampleIndex)
{
    float4 noise = SampleBlueNoiseLod(texcoord);

    // Use different channels for different sample indices
    float2 offset;
    if ((uint(sampleIndex) & 1u) == 0u)
        offset = noise.rg;
    else
        offset = noise.ba;

    // Add temporal jitter
    float temporalPhase = float(framecount & 15u) / 16.0;
    offset = frac(offset + temporalPhase);

    return offset;
}

/**
 * Generate Hammersley sequence point (low-discrepancy sampling)
 */
float2 Hammersley(int i, int N)
{
    // Manual bit reversal (Van der Corput sequence) - avoids reversebits() compatibility issues
    uint bits = uint(i);
    bits = (bits << 16u) | (bits >> 16u);
    bits = ((bits & 0x55555555u) << 1u) | ((bits & 0xAAAAAAAAu) >> 1u);
    bits = ((bits & 0x33333333u) << 2u) | ((bits & 0xCCCCCCCCu) >> 2u);
    bits = ((bits & 0x0F0F0F0Fu) << 4u) | ((bits & 0xF0F0F0F0u) >> 4u);
    bits = ((bits & 0x00FF00FFu) << 8u) | ((bits & 0xFF00FF00u) >> 8u);
    float ri = float(bits) * 2.3283064365386963e-10; // Divide by 0x100000000
    return float2(float(uint(i)) / float(uint(N)), ri);
}

/**
 * Generate cosine-weighted hemisphere sample
 */
float3 CosineSampleHemisphere(float2 u, float3 normal)
{
    // Map uniform random to cosine-weighted hemisphere
    float phi = TWO_PI * u.x;
    float cosTheta = sqrt(u.y);
    float sinTheta = sqrt(1.0 - cosTheta * cosTheta);

    // Spherical to Cartesian in tangent space
    float3 tangentSample = float3(
        cos(phi) * sinTheta,
        sin(phi) * sinTheta,
        cosTheta
    );

    // Build tangent space from normal
    float3 up = abs(normal.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
    float3 tangent = normalize(cross(up, normal));
    float3 bitangent = cross(normal, tangent);

    // Transform to world space
    return tangent * tangentSample.x + bitangent * tangentSample.y + normal * tangentSample.z;
}

//==============================================================================
// Material Property Estimation
//==============================================================================

/**
 * Estimate material roughness from color variance
 * Rougher materials tend to have more color variation
 */
float EstimateRoughness(float2 texcoord, sampler2D colorTex)
{
    float3 colorC = tex2D(colorTex, texcoord).rgb;

    // Sample neighbors
    float3 colorL = tex2D(colorTex, texcoord + float2(-pixelsize.x, 0)).rgb;
    float3 colorR = tex2D(colorTex, texcoord + float2(pixelsize.x, 0)).rgb;
    float3 colorU = tex2D(colorTex, texcoord + float2(0, -pixelsize.y)).rgb;
    float3 colorD = tex2D(colorTex, texcoord + float2(0, pixelsize.y)).rgb;

    // Calculate variance
    float3 variance = float3(0, 0, 0);
    variance += abs(colorC - colorL);
    variance += abs(colorC - colorR);
    variance += abs(colorC - colorU);
    variance += abs(colorC - colorD);
    variance /= 4.0;

    // Average variance across channels
    float avgVariance = (variance.r + variance.g + variance.b) / 3.0;

    // Map variance to roughness [0.1, 0.9]
    // Low variance = smooth surface, high variance = rough surface
    float roughness = saturate(avgVariance * 5.0);
    roughness = lerp(0.1, 0.9, roughness);

    return roughness;
}

/**
 * Estimate material metallicness from color saturation and brightness
 * Metallic surfaces tend to be saturated and preserve color in reflections
 */
float EstimateMetalness(float3 color)
{
    // Calculate saturation
    float maxChannel = max(max(color.r, color.g), color.b);
    float minChannel = min(min(color.r, color.g), color.b);
    float saturation = (maxChannel - minChannel) / (maxChannel + EPSILON);

    // Calculate brightness
    float brightness = (color.r + color.g + color.b) / 3.0;

    // Metallic surfaces are typically saturated and not too dark
    float metalness = saturation * smoothstep(0.2, 0.8, brightness);

    return saturate(metalness);
}

/**
 * Estimate material reflectivity (Fresnel F0)
 */
float3 EstimateF0(float3 color, float metalness)
{
    // Non-metals have low F0 (0.04), metals use albedo as F0
    float3 dielectricF0 = float3(0.04, 0.04, 0.04);
    return lerp(dielectricF0, color, metalness);
}

//==============================================================================
// BRDF and Fresnel
//==============================================================================

/**
 * Schlick's Fresnel approximation
 */
float3 FresnelSchlick(float cosTheta, float3 F0)
{
    return F0 + (1.0 - F0) * pow(saturate(1.0 - cosTheta), 5.0);
}

/**
 * Fresnel with roughness consideration
 */
float3 FresnelSchlickRoughness(float cosTheta, float3 F0, float roughness)
{
    return F0 + (max(float3(1.0 - roughness, 1.0 - roughness, 1.0 - roughness), F0) - F0) * pow(saturate(1.0 - cosTheta), 5.0);
}

/**
 * GGX/Trowbridge-Reitz normal distribution function
 */
float DistributionGGX(float3 N, float3 H, float roughness)
{
    float a = roughness * roughness;
    float a2 = a * a;
    float NdotH = max(dot(N, H), 0.0);
    float NdotH2 = NdotH * NdotH;

    float nom = a2;
    float denom = (NdotH2 * (a2 - 1.0) + 1.0);
    denom = PI * denom * denom;

    return nom / max(denom, EPSILON);
}

//==============================================================================
// Ray Marching Utilities
//==============================================================================

/**
 * Ray march through screen space
 * Returns hit information: .xyz = hit UV + depth, .w = confidence [0,1]
 */
float4 ScreenSpaceRayMarch(
    float3 rayOrigin,      // View-space origin
    float3 rayDir,         // View-space direction
    int maxSteps,          // Maximum ray march steps
    float maxDistance,     // Maximum ray distance
    float thickness        // Surface thickness for hit detection
)
{
    float4 result = float4(0, 0, 0, 0); // UV.xy, depth.z, confidence.w

    float3 rayPos = rayOrigin;
    float stepSize = maxDistance / float(maxSteps);

    [loop]
    for (int i = 0; i < maxSteps; i++)
    {
        // Advance ray
        rayPos += rayDir * stepSize;

        // Project to screen space
        float4 projectedPos = float4(rayPos, 1.0);

        // Convert to UV coordinates (simplified projection)
        float2 rayUV = float2(
            projectedPos.x / (projectedPos.z * 2.0) + 0.5,
            projectedPos.y / (projectedPos.z * 2.0) + 0.5
        );

        // Check bounds
        if (any(rayUV < 0) || any(rayUV > 1))
            break;

        // Sample depth at ray position (use LOD version in loop)
        float sceneDepth = SampleDepthLod(rayUV);
        float rayDepth = length(rayPos);

        // Check for intersection
        float depthDiff = (LinearizeDepth(sceneDepth) - rayDepth);

        if (depthDiff > 0 && depthDiff < thickness)
        {
            // Hit!
            float confidence = 1.0 - (float(i) / float(maxSteps)); // Closer hits = higher confidence
            confidence *= 1.0 - smoothstep(0.0, 0.2, max(abs(rayUV.x - 0.5), abs(rayUV.y - 0.5)) * 2.0); // Fade at edges

            result = float4(rayUV, sceneDepth, confidence);
            break;
        }
    }

    return result;
}

//==============================================================================
// Utility Functions
//==============================================================================

/**
 * Convert RGB to luminance
 */
float Luminance(float3 color)
{
    return dot(color, float3(0.2126, 0.7152, 0.0722));
}

/**
 * Safe normalize (returns zero vector if input is zero)
 */
float3 SafeNormalize(float3 v)
{
    float len = length(v);
    return len > EPSILON ? v / len : float3(0, 0, 0);
}

/**
 * Smooth minimum function (useful for blending)
 */
float SmoothMin(float a, float b, float k)
{
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * h * k * (1.0 / 6.0);
}

/**
 * Remap value from one range to another
 */
float Remap(float value, float inMin, float inMax, float outMin, float outMax)
{
    return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin);
}

/**
 * Smooth exponential falloff
 */
float ExponentialFalloff(float distance, float range)
{
    return exp(-distance / max(range, EPSILON));
}
