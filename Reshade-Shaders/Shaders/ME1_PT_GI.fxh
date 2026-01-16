/*==============================================================================
    ME1 Path Tracing - Global Illumination

    Temporal screen-space global illumination with multiple light bounces.
    Implements importance-sampled indirect lighting with noise reduction.

    Features:
    - Multi-bounce indirect lighting (2-3 bounces)
    - Importance sampling based on BRDF
    - Temporal accumulation (16-32 frames)
    - Hierarchical ray marching for performance
    - Disocclusion detection and fallback
==============================================================================*/

#pragma once
#include "ME1_PT_Common.fxh"

//==============================================================================
// GI Parameters
//==============================================================================

#ifndef GI_RAY_COUNT
    #define GI_RAY_COUNT 12
#endif

#ifndef GI_MAX_BOUNCES
    #define GI_MAX_BOUNCES 2
#endif

#ifndef GI_MAX_RAY_DISTANCE
    #define GI_MAX_RAY_DISTANCE 80.0
#endif

#ifndef GI_RAY_MARCH_STEPS
    #define GI_RAY_MARCH_STEPS 32
#endif

//==============================================================================
// Hierarchical Ray Marching
//==============================================================================

/**
 * Advanced hierarchical ray marching with adaptive step size
 * Returns: .xyz = hit color, .w = hit confidence
 */
float4 HierarchicalRayMarch(
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
    float rayDist = 0.0;

    // Adaptive step sizing: start small, grow as we go
    float baseStepSize = maxDistance / float(maxSteps);
    float currentStepSize = baseStepSize * 0.5; // Start with half step

    float3 hitColor = float3(0, 0, 0);
    float hitConfidence = 0.0;

    [loop]
    for (int i = 0; i < maxSteps; i++)
    {
        // Advance ray with adaptive step size
        rayPos += rayDir * currentStepSize;
        rayDist += currentStepSize;

        // Project to screen space (simplified perspective projection)
        float3 projPos = rayPos;
        float w = -projPos.z;

        if (w <= 0) // Behind camera
            break;

        // Convert to UV
        float2 rayUV = float2(
            projPos.x / (w * 2.0) + 0.5,
            -projPos.y / (w * 2.0) + 0.5
        );

        #if RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN
            rayUV.y = 1.0 - rayUV.y;
        #endif

        // Check bounds with smooth fade at edges
        if (any(rayUV < 0.05) || any(rayUV > 0.95))
        {
            hitConfidence *= saturate(1.0 - max(abs(rayUV.x - 0.5), abs(rayUV.y - 0.5)) * 2.0);
            break;
        }

        // Sample scene depth
        float sceneDepth = SampleDepth(rayUV);

        if (IsSky(sceneDepth))
        {
            // Hit sky - use as ambient light source
            hitColor = float3(0.5, 0.6, 0.7); // Sky color approximation
            hitConfidence = 0.3; // Low confidence for sky hits
            break;
        }

        float sceneZ = LinearizeDepth(sceneDepth);
        float rayZ = length(rayPos);

        // Check for intersection
        float depthDiff = sceneZ - rayZ;

        if (depthDiff > 0 && depthDiff < thickness)
        {
            // Hit surface!
            hitColor = tex2Dlod(colorTex, float4(rayUV, 0, 0)).rgb;

            // Calculate confidence based on:
            // - Distance (closer = higher confidence)
            // - Edge proximity (center = higher confidence)
            // - Depth precision (small depth diff = higher confidence)
            float distanceConfidence = 1.0 - saturate(rayDist / maxDistance);
            float edgeConfidence = 1.0 - smoothstep(0.7, 0.95, max(abs(rayUV.x - 0.5), abs(rayUV.y - 0.5)) * 2.0);
            float depthConfidence = 1.0 - saturate(depthDiff / thickness);

            hitConfidence = distanceConfidence * edgeConfidence * depthConfidence;
            break;
        }
        else if (depthDiff < 0)
        {
            // Ray is in front of surface, reduce step size for better precision
            currentStepSize = max(currentStepSize * 0.5, baseStepSize * 0.25);

            // Back up slightly
            rayPos -= rayDir * currentStepSize;
            rayDist -= currentStepSize;
        }
        else
        {
            // Ray is behind surface but not close enough, increase step size
            currentStepSize = min(currentStepSize * 1.5, baseStepSize * 2.0);
        }

        // Max distance check
        if (rayDist > maxDistance)
            break;
    }

    return float4(hitColor, hitConfidence);
}

//==============================================================================
// Light Bounce Calculation
//==============================================================================

/**
 * Calculate indirect lighting for a single bounce
 */
float3 CalculateIndirectLightingBounce(
    float2 texcoord,
    float3 viewPos,
    float3 viewNormal,
    float3 albedo,
    sampler2D colorTex,
    int rayCount,
    float rayDistance,
    float3 bentNormal, // From AO for importance sampling
    float aoValue
)
{
    float3 indirectLight = float3(0, 0, 0);
    float totalWeight = 0.0;

    // Use bent normal to bias sampling towards unoccluded directions
    float3 samplingNormal = normalize(lerp(viewNormal, bentNormal, 0.5));

    [loop]
    for (int i = 0; i < rayCount; i++)
    {
        // Get low-discrepancy sample
        float2 xi = Hammersley(i, rayCount);

        // Add temporal and spatial variation
        float2 blueNoise = GetBlueNoiseOffset(texcoord, i);
        xi = frac(xi + blueNoise);

        // Generate cosine-weighted hemisphere sample
        float3 rayDir = CosineSampleHemisphere(xi, samplingNormal);

        // Importance sampling weight (cosine-weighted already accounted for in sampling)
        float NdotL = max(0, dot(viewNormal, rayDir));

        if (NdotL < 0.01)
            continue;

        // Ray march to find indirect light
        float thickness = 2.0 + length(viewPos) * 0.05; // Adaptive thickness
        float4 hitResult = HierarchicalRayMarch(
            viewPos,
            rayDir,
            texcoord,
            colorTex,
            GI_RAY_MARCH_STEPS,
            rayDistance,
            thickness
        );

        float3 hitColor = hitResult.rgb;
        float hitConfidence = hitResult.a;

        if (hitConfidence > 0.01)
        {
            // Apply Lambert's cosine law
            float3 indirectContribution = hitColor * NdotL;

            // Apply AO influence (occluded areas receive less indirect light)
            indirectContribution *= lerp(aoValue, 1.0, 0.3);

            indirectLight += indirectContribution * hitConfidence;
            totalWeight += hitConfidence;
        }
        else
        {
            // Ray miss - use ambient fallback
            float3 ambientFallback = float3(0.4, 0.5, 0.6) * NdotL; // Approximate ambient
            indirectLight += ambientFallback * 0.2;
            totalWeight += 0.2;
        }
    }

    // Normalize by total weight
    if (totalWeight > 0.01)
        indirectLight /= totalWeight;

    return indirectLight;
}

/**
 * Calculate multi-bounce global illumination
 */
float3 CalculateGlobalIllumination(
    float2 texcoord,
    sampler2D colorTex,
    int rayCount,
    int numBounces,
    float maxRayDistance,
    float3 bentNormal,
    float aoValue
)
{
    float depth = SampleDepth(texcoord);

    // Early out for sky
    if (IsSky(depth))
        return float3(0, 0, 0);

    // Reconstruct geometry
    float3 viewPos = GetViewPosition(texcoord, depth);
    float3 viewNormal = ReconstructNormalImproved(texcoord);
    float3 albedo = tex2D(colorTex, texcoord).rgb;

    // Accumulated indirect lighting
    float3 totalIndirectLight = float3(0, 0, 0);
    float bounceIntensity = 1.0;

    // Calculate first bounce (most important)
    float3 bounce1Light = CalculateIndirectLightingBounce(
        texcoord,
        viewPos,
        viewNormal,
        albedo,
        colorTex,
        rayCount,
        maxRayDistance,
        bentNormal,
        aoValue
    );

    totalIndirectLight += bounce1Light * bounceIntensity;

    // Additional bounces with decreasing intensity
    if (numBounces > 1)
    {
        bounceIntensity *= 0.6; // Energy loss per bounce

        // For second bounce, use result from first bounce
        // This is approximated by sampling the scene again with reduced intensity
        float3 bounce2Light = CalculateIndirectLightingBounce(
            texcoord,
            viewPos,
            viewNormal,
            albedo,
            colorTex,
            max(rayCount / 2, 4), // Fewer rays for second bounce
            maxRayDistance * 0.7, // Shorter rays for second bounce
            bentNormal,
            aoValue
        );

        totalIndirectLight += bounce2Light * bounceIntensity;
    }

    if (numBounces > 2)
    {
        bounceIntensity *= 0.5;

        float3 bounce3Light = CalculateIndirectLightingBounce(
            texcoord,
            viewPos,
            viewNormal,
            albedo,
            colorTex,
            max(rayCount / 4, 4),
            maxRayDistance * 0.5,
            bentNormal,
            aoValue
        );

        totalIndirectLight += bounce3Light * bounceIntensity;
    }

    return totalIndirectLight * albedo; // Modulate by surface albedo
}

//==============================================================================
// Quality Levels
//==============================================================================

/**
 * Calculate GI with quality level presets
 */
float3 CalculateGIWithQuality(
    float2 texcoord,
    sampler2D colorTex,
    int qualityLevel, // 0=low, 1=medium, 2=high, 3=ultra
    float3 bentNormal,
    float aoValue
)
{
    int rayCount = 4;
    int numBounces = 1;
    float maxDistance = 40.0;

    switch (qualityLevel)
    {
        case 0: // Low
            rayCount = 4;
            numBounces = 1;
            maxDistance = 30.0;
            break;
        case 1: // Medium
            rayCount = 8;
            numBounces = 2;
            maxDistance = 50.0;
            break;
        case 2: // High
            rayCount = 12;
            numBounces = 2;
            maxDistance = 70.0;
            break;
        case 3: // Ultra
            rayCount = 16;
            numBounces = 3;
            maxDistance = 100.0;
            break;
    }

    return CalculateGlobalIllumination(
        texcoord,
        colorTex,
        rayCount,
        numBounces,
        maxDistance,
        bentNormal,
        aoValue
    );
}

//==============================================================================
// Temporal Accumulation
//==============================================================================

/**
 * Temporal accumulation with disocclusion detection
 */
float3 TemporalAccumulateGI(
    float2 texcoord,
    float3 currentGI,
    sampler2D previousGITex,
    sampler2D previousDepthTex,
    float blendFactor
)
{
    float currentDepth = SampleDepth(texcoord);

    // Estimate motion
    float2 motionVector = EstimateMotionVector(texcoord, currentDepth, previousDepthTex);
    float2 prevUV = texcoord + motionVector;

    // Check validity
    float previousDepth = tex2D(previousDepthTex, prevUV).r;
    bool validReprojection = IsReprojectionValid(prevUV, currentDepth, previousDepth);

    if (validReprojection)
    {
        float3 previousGI = tex2D(previousGITex, prevUV).rgb;

        // Check for significant color change (possible disocclusion)
        float colorDiff = length(currentGI - previousGI);
        float maxColorDiff = 0.5;

        if (colorDiff < maxColorDiff)
        {
            // Blend with history
            float3 blendedGI = lerp(currentGI, previousGI, blendFactor);

            // Clamp to prevent ghosting
            float3 giMin = currentGI * 0.5;
            float3 giMax = currentGI * 2.0;
            blendedGI = clamp(blendedGI, giMin, giMax);

            return blendedGI;
        }
    }

    // No valid history or disocclusion detected
    return currentGI;
}

//==============================================================================
// Denoising
//==============================================================================

/**
 * Variance-guided spatial filter for GI denoising
 */
float3 DenoiseGI(
    float2 texcoord,
    sampler2D giTex,
    float strength
)
{
    float depth = SampleDepth(texcoord);

    if (IsSky(depth))
        return tex2D(giTex, texcoord).rgb;

    float3 centerGI = tex2D(giTex, texcoord).rgb;
    float3 centerNormal = ReconstructNormal(texcoord);

    // Calculate local variance
    float3 variance = float3(0, 0, 0);
    const int varianceRadius = 1;

    [loop]
    for (int y = -varianceRadius; y <= varianceRadius; y++)
    {
        [loop]
        for (int x = -varianceRadius; x <= varianceRadius; x++)
        {
            float2 offset = float2(x, y) * pixelsize;
            float3 sampleGI = tex2D(giTex, texcoord + offset).rgb;
            variance += abs(sampleGI - centerGI);
        }
    }

    variance /= 9.0;
    float avgVariance = (variance.r + variance.g + variance.b) / 3.0;

    // Adaptive blur radius based on variance (high variance = more blur needed)
    float blurRadius = lerp(0.5, 2.0, saturate(avgVariance * 5.0)) * strength;

    // Edge-preserving bilateral filter
    float3 filteredGI = float3(0, 0, 0);
    float totalWeight = 0.0;

    const int kernelRadius = 2;

    [loop]
    for (int y = -kernelRadius; y <= kernelRadius; y++)
    {
        [loop]
        for (int x = -kernelRadius; x <= kernelRadius; x++)
        {
            float2 offset = float2(x, y) * pixelsize * blurRadius;
            float2 sampleUV = texcoord + offset;

            if (any(sampleUV < 0) || any(sampleUV > 1))
                continue;

            float sampleDepth = SampleDepth(sampleUV);
            float3 sampleGI = tex2D(giTex, sampleUV).rgb;
            float3 sampleNormal = ReconstructNormal(sampleUV);

            // Bilateral weights
            float depthWeight = exp(-abs(sampleDepth - depth) * 20.0);
            float normalWeight = pow(max(0, dot(centerNormal, sampleNormal)), 8.0);
            float spatialWeight = exp(-float(x*x + y*y) / (2.0 * blurRadius * blurRadius));

            float weight = depthWeight * normalWeight * spatialWeight;

            filteredGI += sampleGI * weight;
            totalWeight += weight;
        }
    }

    if (totalWeight > 0)
        filteredGI /= totalWeight;
    else
        filteredGI = centerGI;

    return filteredGI;
}

/**
 * Firefly suppression (clamp extreme values)
 */
float3 SuppressFireflies(float3 gi, float threshold)
{
    float luminance = Luminance(gi);

    if (luminance > threshold)
    {
        // Clamp to threshold while preserving color
        gi = gi * (threshold / luminance);
    }

    return gi;
}

//==============================================================================
// Main Entry Points
//==============================================================================

/**
 * Complete GI calculation with all features
 */
float3 ComputeGlobalIllumination(
    float2 texcoord,
    sampler2D colorTex,
    int qualityLevel,
    float intensity,
    float3 bentNormal,
    float aoValue
)
{
    // Calculate GI
    float3 gi = CalculateGIWithQuality(
        texcoord,
        colorTex,
        qualityLevel,
        bentNormal,
        aoValue
    );

    // Suppress fireflies
    gi = SuppressFireflies(gi, 10.0);

    // Apply intensity
    gi *= intensity;

    return gi;
}
