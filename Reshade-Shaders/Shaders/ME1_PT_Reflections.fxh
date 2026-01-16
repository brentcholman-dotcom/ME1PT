/*==============================================================================
    ME1 Path Tracing - Screen-Space Reflections

    Stochastic screen-space reflections with cone tracing for glossy surfaces.
    Includes temporal filtering and material-aware roughness.

    Features:
    - Adaptive ray marching (64-128 steps)
    - Cone tracing for glossy/rough reflections
    - Material roughness estimation
    - Fresnel calculations
    - Temporal accumulation
    - Distance-based fade
==============================================================================*/

#pragma once
#include "ME1_PT_Common.fxh"

//==============================================================================
// Reflection Parameters
//==============================================================================

#ifndef SSR_MAX_STEPS
    #define SSR_MAX_STEPS 96
#endif

#ifndef SSR_MAX_DISTANCE
    #define SSR_MAX_DISTANCE 75.0
#endif

#ifndef SSR_THICKNESS
    #define SSR_THICKNESS 1.5
#endif

//==============================================================================
// Advanced Ray Marching for Reflections
//==============================================================================

/**
 * High-quality ray marching with binary search refinement
 */
float4 RayMarchReflection(
    float3 rayOrigin,
    float3 rayDir,
    float2 originTexcoord,
    sampler2D colorTex,
    int maxSteps,
    float maxDistance,
    float thickness
)
{
    float3 rayPos = rayOrigin;
    float stepSize = maxDistance / float(maxSteps);

    float3 hitColor = float3(0, 0, 0);
    float2 hitUV = float2(0, 0);
    float hitConfidence = 0.0;
    bool hit = false;

    // Initial ray march
    [loop]
    for (int i = 0; i < maxSteps; i++)
    {
        rayPos += rayDir * stepSize;

        // Project to screen space
        float w = -rayPos.z;

        if (w <= 0)
            break;

        float2 rayUV = float2(
            rayPos.x / (w * 2.0) + 0.5,
            -rayPos.y / (w * 2.0) + 0.5
        );

        #if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
            rayUV.y = 1.0 - rayUV.y;
        #endif

        // Check bounds
        if (any(rayUV < 0) || any(rayUV > 1))
            break;

        // Sample depth
        float sceneDepth = SampleDepthLod(rayUV);

        if (IsSky(sceneDepth))
            continue;

        float sceneZ = LinearizeDepth(sceneDepth);
        float rayZ = length(rayPos);

        float depthDiff = sceneZ - rayZ;

        if (depthDiff > 0 && depthDiff < thickness)
        {
            // Hit found, store initial hit location
            hit = true;
            hitUV = rayUV;

            // Binary search refinement for better accuracy
            float3 refinedRayPos = rayPos - rayDir * stepSize;
            float refinedStepSize = stepSize;

            [loop]
            for (int refinement = 0; refinement < 4; refinement++)
            {
                refinedStepSize *= 0.5;
                refinedRayPos += rayDir * refinedStepSize;

                float refinedW = -refinedRayPos.z;
                float2 refinedUV = float2(
                    refinedRayPos.x / (refinedW * 2.0) + 0.5,
                    -refinedRayPos.y / (refinedW * 2.0) + 0.5
                );

                #if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
                    refinedUV.y = 1.0 - refinedUV.y;
                #endif

                if (any(refinedUV < 0) || any(refinedUV > 1))
                    break;

                float refinedSceneDepth = SampleDepthLod(refinedUV);
                float refinedSceneZ = LinearizeDepth(refinedSceneDepth);
                float refinedRayZ = length(refinedRayPos);

                float refinedDepthDiff = refinedSceneZ - refinedRayZ;

                if (refinedDepthDiff > 0 && refinedDepthDiff < thickness)
                {
                    hitUV = refinedUV;
                    rayPos = refinedRayPos;
                }
                else
                {
                    refinedRayPos -= rayDir * refinedStepSize;
                }
            }

            // Sample color at refined hit location
            hitColor = tex2Dlod(colorTex, float4(hitUV, 0, 0)).rgb;

            // Calculate confidence
            float rayDist = length(rayPos - rayOrigin);
            float distanceConfidence = 1.0 - saturate(rayDist / maxDistance);
            float edgeConfidence = 1.0 - smoothstep(0.8, 1.0, max(abs(hitUV.x - 0.5), abs(hitUV.y - 0.5)) * 2.0);

            hitConfidence = distanceConfidence * edgeConfidence;
            break;
        }
    }

    return float4(hitColor, hitConfidence);
}

/**
 * Cone tracing for glossy reflections
 * Samples multiple rays within a cone based on roughness
 */
float4 ConeTraceReflection(
    float3 rayOrigin,
    float3 rayDir,
    float2 originTexcoord,
    float roughness,
    sampler2D colorTex,
    int sampleCount,
    int maxSteps,
    float maxDistance
)
{
    float3 accumulatedColor = float3(0, 0, 0);
    float totalWeight = 0.0;

    // Cone angle based on roughness
    float coneAngle = roughness * HALF_PI * 0.5; // Max 45 degrees for roughest surfaces

    // Build tangent space from reflection direction
    float3 up = abs(rayDir.z) < 0.999 ? float3(0, 0, 1) : float3(1, 0, 0);
    float3 tangent = normalize(cross(up, rayDir));
    float3 bitangent = cross(rayDir, tangent);

    [loop]
    for (int i = 0; i < sampleCount; i++)
    {
        // Get random sample within cone
        float2 xi = Hammersley(i, sampleCount);
        float2 noiseOffset = GetBlueNoiseOffset(originTexcoord, i);
        xi = frac(xi + noiseOffset);

        // Map to cone
        float phi = TWO_PI * xi.x;
        float theta = coneAngle * xi.y;

        // Convert to Cartesian in cone space
        float sinTheta = sin(theta);
        float cosTheta = cos(theta);
        float3 coneDir = float3(
            cos(phi) * sinTheta,
            sin(phi) * sinTheta,
            cosTheta
        );

        // Transform to world space
        float3 sampleRayDir = normalize(
            tangent * coneDir.x +
            bitangent * coneDir.y +
            rayDir * coneDir.z
        );

        // Trace this sample
        float4 sampleResult = RayMarchReflection(
            rayOrigin,
            sampleRayDir,
            originTexcoord,
            colorTex,
            maxSteps,
            maxDistance,
            SSR_THICKNESS
        );

        float sampleConfidence = sampleResult.a;

        if (sampleConfidence > 0.01)
        {
            // Weight by confidence and distance from cone center
            float weight = sampleConfidence * cosTheta;
            accumulatedColor += sampleResult.rgb * weight;
            totalWeight += weight;
        }
    }

    // Normalize
    if (totalWeight > 0.01)
    {
        accumulatedColor /= totalWeight;
        return float4(accumulatedColor, totalWeight / float(sampleCount));
    }
    else
    {
        return float4(0, 0, 0, 0);
    }
}

//==============================================================================
// Reflection Calculation
//==============================================================================

/**
 * Calculate screen-space reflection with material awareness
 */
float4 CalculateReflection(
    float2 texcoord,
    sampler2D colorTex,
    int qualityLevel,
    float roughnessOverride // -1 to use estimated roughness
)
{
    float depth = SampleDepth(texcoord);

    // Early out for sky
    if (IsSky(depth))
        return float4(0, 0, 0, 0);

    // Reconstruct geometry
    float3 viewPos = GetViewPosition(texcoord, depth);
    float3 viewNormal = ReconstructNormalImproved(texcoord);
    float3 viewDir = normalize(-viewPos);
    float3 albedo = tex2D(colorTex, texcoord).rgb;

    // Calculate reflection direction
    float3 reflectionDir = reflect(-viewDir, viewNormal);

    // Estimate or use provided roughness
    float roughness = (roughnessOverride < 0) ?
                      EstimateRoughness(texcoord, colorTex) :
                      roughnessOverride;

    // Determine sample count and steps based on quality
    int sampleCount = 1;
    int maxSteps = 64;
    float maxDistance = 50.0;

    switch (qualityLevel)
    {
        case 0: // Low
            sampleCount = 1;
            maxSteps = 48;
            maxDistance = 40.0;
            break;
        case 1: // Medium
            sampleCount = 2;
            maxSteps = 64;
            maxDistance = 60.0;
            break;
        case 2: // High
            sampleCount = 4;
            maxSteps = 96;
            maxDistance = 75.0;
            break;
        case 3: // Ultra
            sampleCount = 8;
            maxSteps = 128;
            maxDistance = 100.0;
            break;
    }

    // Adjust sample count based on roughness (smoother = fewer samples needed)
    sampleCount = max(1, int(float(sampleCount) * lerp(1.0, 4.0, roughness)));

    // Cone trace reflection
    float4 reflectionResult;

    if (roughness < 0.05)
    {
        // Very smooth surface, use single high-quality ray
        reflectionResult = RayMarchReflection(
            viewPos,
            reflectionDir,
            texcoord,
            colorTex,
            maxSteps,
            maxDistance,
            SSR_THICKNESS
        );
    }
    else
    {
        // Glossy/rough surface, use cone tracing
        reflectionResult = ConeTraceReflection(
            viewPos,
            reflectionDir,
            texcoord,
            roughness,
            colorTex,
            sampleCount,
            maxSteps,
            maxDistance
        );
    }

    // Calculate Fresnel
    float NdotV = max(0, dot(viewNormal, viewDir));
    float metalness = EstimateMetalness(albedo);
    float3 F0 = EstimateF0(albedo, metalness);
    float3 fresnel = FresnelSchlickRoughness(NdotV, F0, roughness);

    // Apply Fresnel to reflection
    float3 reflectionColor = reflectionResult.rgb * fresnel;
    float reflectionConfidence = reflectionResult.a;

    // Fade out at grazing angles for rough surfaces
    float grazingFade = pow(max(0.001, NdotV), lerp(0.5, 2.0, roughness));
    reflectionConfidence *= grazingFade;

    return float4(reflectionColor, reflectionConfidence);
}

//==============================================================================
// Temporal Accumulation
//==============================================================================

/**
 * Temporal accumulation for reflections
 */
float4 TemporalAccumulateReflection(
    float2 texcoord,
    float4 currentReflection,
    sampler2D previousReflectionTex,
    sampler2D previousDepthTex,
    float blendFactor
)
{
    float currentDepth = SampleDepth(texcoord);

    if (IsSky(currentDepth))
        return float4(0, 0, 0, 0);

    // Estimate motion
    float2 motionVector = EstimateMotionVector(texcoord, currentDepth, previousDepthTex);
    float2 prevUV = texcoord + motionVector;

    // Check validity
    float previousDepth = tex2D(previousDepthTex, prevUV).r;
    bool validReprojection = IsReprojectionValid(prevUV, currentDepth, previousDepth);

    if (validReprojection)
    {
        float4 previousReflection = tex2D(previousReflectionTex, prevUV);

        // Check confidence - don't blend if previous confidence is too low
        if (previousReflection.a > 0.1)
        {
            // Blend RGB and confidence separately
            float3 blendedColor = lerp(currentReflection.rgb, previousReflection.rgb, blendFactor);
            float blendedConfidence = lerp(currentReflection.a, previousReflection.a, blendFactor * 0.8);

            // Clamp to prevent ghosting
            float3 colorMin = currentReflection.rgb * 0.5;
            float3 colorMax = currentReflection.rgb * 2.0;
            blendedColor = clamp(blendedColor, colorMin, colorMax);

            return float4(blendedColor, blendedConfidence);
        }
    }

    // No valid history
    return currentReflection;
}

//==============================================================================
// Denoising
//==============================================================================

/**
 * Edge-aware reflection denoising
 */
float4 DenoiseReflection(
    float2 texcoord,
    sampler2D reflectionTex,
    float strength
)
{
    float depth = SampleDepth(texcoord);

    if (IsSky(depth))
        return float4(0, 0, 0, 0);

    float4 centerReflection = tex2D(reflectionTex, texcoord);

    // Skip denoising if confidence is very high (clean reflections)
    if (centerReflection.a > 0.95)
        return centerReflection;

    float3 centerNormal = ReconstructNormal(texcoord);

    // Adaptive kernel size based on confidence (low confidence = more blur)
    float blurRadius = lerp(2.0, 0.5, centerReflection.a) * strength;

    float4 filteredReflection = centerReflection; // Initialize to center value
    float totalWeight = 0.0;

    const int kernelRadius = 2;

    [loop]
    for (int ry = -kernelRadius; ry <= kernelRadius; ry++)
    {
        [loop]
        for (int rx = -kernelRadius; rx <= kernelRadius; rx++)
        {
            float2 offset = float2(rx, ry) * pixelsize * blurRadius;
            float2 sampleUV = texcoord + offset;

            if (any(sampleUV < 0) || any(sampleUV > 1))
                continue;

            float sampleDepth = SampleDepthLod(sampleUV);
            float4 sampleReflection = tex2Dlod(reflectionTex, float4(sampleUV, 0, 0));
            float3 sampleNormal = ReconstructNormalLod(sampleUV);

            // Bilateral weights
            float depthWeight = exp(-abs(sampleDepth - depth) * 30.0);
            float normalWeight = pow(max(0, dot(centerNormal, sampleNormal)), 16.0);
            float confidenceWeight = saturate(sampleReflection.a * 2.0);
            float spatialWeight = exp(-float(rx*rx + ry*ry) / (2.0 * blurRadius * blurRadius));

            float weight = depthWeight * normalWeight * confidenceWeight * spatialWeight;

            filteredReflection += sampleReflection * weight;
            totalWeight += weight;
        }
    }

    if (totalWeight > 0.01)
        filteredReflection /= totalWeight;
    else
        filteredReflection = centerReflection;

    return filteredReflection;
}

//==============================================================================
// Contact Hardening (Distance-based blur)
//==============================================================================

/**
 * Apply contact hardening - sharper reflections near contact points
 */
float4 ApplyContactHardening(
    float2 texcoord,
    float4 reflection,
    sampler2D colorTex
)
{
    // Estimate distance to reflected surface based on reflection confidence
    // High confidence usually means close reflection
    float surfaceProximity = reflection.a;

    // Rough surfaces and distant reflections should be blurrier
    float roughness = EstimateRoughness(texcoord, colorTex);

    // Combine factors
    float blur = (1.0 - surfaceProximity) * roughness;

    // This would ideally be applied during the cone trace
    // but we can approximate it here by modulating confidence
    reflection.a *= lerp(1.0, 0.5, blur);

    return reflection;
}

//==============================================================================
// Main Entry Point
//==============================================================================

/**
 * Complete reflection calculation with all features
 */
float4 ComputeScreenSpaceReflections(
    float2 texcoord,
    sampler2D colorTex,
    int qualityLevel,
    float intensity,
    float roughnessOverride
)
{
    // Calculate reflection
    float4 reflection = CalculateReflection(
        texcoord,
        colorTex,
        qualityLevel,
        roughnessOverride
    );

    // Apply contact hardening
    reflection = ApplyContactHardening(texcoord, reflection, colorTex);

    // Apply intensity
    reflection.rgb *= intensity;

    // Clamp to prevent fireflies
    float maxReflectionIntensity = 5.0;
    float reflectionLuminance = Luminance(reflection.rgb);
    if (reflectionLuminance > maxReflectionIntensity)
    {
        reflection.rgb *= maxReflectionIntensity / reflectionLuminance;
    }

    return reflection;
}
