/*==============================================================================
    ME1 Path Tracing - Ambient Occlusion (GTAO)

    Ground Truth Ambient Occlusion with bent normals and temporal accumulation.
    Based on "Practical Realtime Strategies for Accurate Indirect Occlusion"

    Features:
    - Multi-scale GTAO sampling
    - Bent normal calculation for directional occlusion
    - Temporal accumulation for noise reduction
    - Integration-ready for GI influence
==============================================================================*/

#pragma once
#include "ME1_PT_Common.fxh"

//==============================================================================
// GTAO Parameters
//==============================================================================

// Number of spatial directions to sample
#ifndef AO_DIRECTIONS
    #define AO_DIRECTIONS 6
#endif

// Number of steps per direction
#ifndef AO_STEPS_PER_DIRECTION
    #define AO_STEPS_PER_DIRECTION 3
#endif

//==============================================================================
// GTAO Helper Functions
//==============================================================================

/**
 * Calculate horizon angle for a given direction and step
 */
float CalculateHorizonAngle(
    float3 viewPos,
    float3 viewNormal,
    float3 viewDir,
    float2 texcoord,
    float2 direction,
    float stepSize,
    int stepIndex
)
{
    // Calculate sample position
    float2 sampleOffset = direction * stepSize * float(stepIndex + 1);
    float2 sampleUV = texcoord + sampleOffset;

    // Check bounds
    if (any(sampleUV < 0) || any(sampleUV > 1))
        return -PI / 2.0; // No occlusion outside screen

    // Sample depth and reconstruct position (use LOD version - called from loop)
    float sampleDepth = SampleDepthLod(sampleUV);
    float3 samplePos = GetViewPosition(sampleUV, sampleDepth);

    // Calculate horizon vector
    float3 horizonVec = samplePos - viewPos;
    float horizonDist = length(horizonVec);

    // Early out if sample is too far (reduces occlusion from distant objects)
    if (horizonDist > 100.0) // Max AO radius
        return -PI / 2.0;

    horizonVec /= horizonDist;

    // Calculate horizon angle relative to view direction
    float horizonAngle = asin(saturate(dot(horizonVec, viewNormal)));

    // Thickness heuristic: reduce occlusion for samples that are too far behind the surface
    float thickness = 5.0; // Approximate surface thickness
    float behindness = max(0, dot(viewNormal, -horizonVec));
    if (horizonDist * behindness > thickness)
    {
        // Sample is behind the surface plane by more than thickness, reduce its contribution
        float falloff = saturate(1.0 - (horizonDist * behindness - thickness) / thickness);
        horizonAngle = lerp(-PI / 2.0, horizonAngle, falloff);
    }

    return horizonAngle;
}

/**
 * Integrate occlusion for a single direction slice
 */
float IntegrateOcclusionSlice(
    float3 viewPos,
    float3 viewNormal,
    float3 viewDir,
    float2 texcoord,
    float2 sliceDir,
    float stepSize,
    out float3 bentNormal
)
{
    bentNormal = viewNormal;

    float maxHorizonAngle = -PI / 2.0;
    float minHorizonAngle = PI / 2.0;

    // Sample both positive and negative directions
    [loop]
    for (int i = 0; i < AO_STEPS_PER_DIRECTION; i++)
    {
        // Positive direction
        float horizonAnglePos = CalculateHorizonAngle(
            viewPos, viewNormal, viewDir, texcoord,
            sliceDir, stepSize, i
        );
        maxHorizonAngle = max(maxHorizonAngle, horizonAnglePos);

        // Negative direction
        float horizonAngleNeg = CalculateHorizonAngle(
            viewPos, viewNormal, viewDir, texcoord,
            -sliceDir, stepSize, i
        );
        minHorizonAngle = min(minHorizonAngle, horizonAngleNeg);
    }

    // Calculate occlusion
    float sinMaxHorizon = sin(maxHorizonAngle);
    float sinMinHorizon = sin(minHorizonAngle);

    // Ground Truth AO integral approximation
    float occlusion = 0.25 * (
        (sinMaxHorizon - sinMinHorizon) +
        (maxHorizonAngle - minHorizonAngle) * INV_PI
    );

    // Calculate bent normal (average unoccluded direction)
    float avgAngle = (maxHorizonAngle + minHorizonAngle) * 0.5;
    float3 sliceDir3D = float3(sliceDir, 0);

    // Rotate normal towards average unoccluded direction
    float3 tangent = normalize(cross(viewNormal, float3(0, 1, 0)));
    if (length(tangent) < 0.1)
        tangent = normalize(cross(viewNormal, float3(1, 0, 0)));

    float3 bitangent = cross(viewNormal, tangent);
    float3 slicePlane = normalize(tangent * sliceDir.x + bitangent * sliceDir.y);

    bentNormal = normalize(viewNormal * cos(avgAngle) + slicePlane * sin(avgAngle));

    return saturate(occlusion);
}

/**
 * Multi-scale GTAO calculation
 */
float4 CalculateGTAO(
    float2 texcoord,
    float radiusScale,
    int numDirections,
    out float3 bentNormal
)
{
    float depth = SampleDepth(texcoord);

    // Early out for sky
    if (IsSky(depth))
    {
        bentNormal = float3(0, 0, 1);
        return float4(1, 1, 1, 1); // No occlusion
    }

    // Reconstruct view-space position and normal
    float3 viewPos = GetViewPosition(texcoord, depth);
    float3 viewNormal = ReconstructNormalImproved(texcoord);
    float3 viewDir = normalize(-viewPos);

    // Calculate adaptive step size based on depth (closer = smaller steps)
    float viewSpaceRadius = lerp(0.5, 2.0, radiusScale);
    float screenSpaceRadius = viewSpaceRadius / max(abs(viewPos.z), 0.1);
    float stepSize = screenSpaceRadius / float(AO_STEPS_PER_DIRECTION);

    float totalOcclusion = 0.0;
    bentNormal = float3(0, 0, 0);

    // Integrate occlusion across multiple directions
    [loop]
    for (int i = 0; i < numDirections; i++)
    {
        // Get direction with temporal rotation for better distribution
        float angle = (TWO_PI * float(uint(i)) / float(uint(numDirections))) +
                      (framecount * GOLDEN_RATIO * 0.1);

        float2 sliceDir = float2(cos(angle), sin(angle));

        // Add blue noise offset for dithering
        float2 noiseOffset = GetBlueNoiseOffset(texcoord, i) * 0.5 - 0.25;
        sliceDir = normalize(sliceDir + noiseOffset * 0.3);

        // Integrate this slice
        float3 sliceBentNormal;
        float sliceOcclusion = IntegrateOcclusionSlice(
            viewPos, viewNormal, viewDir,
            texcoord, sliceDir, stepSize,
            sliceBentNormal
        );

        totalOcclusion += sliceOcclusion;
        bentNormal += sliceBentNormal;
    }

    // Average results
    totalOcclusion /= float(numDirections);
    bentNormal = SafeNormalize(bentNormal);

    // Final AO value (1 = no occlusion, 0 = full occlusion)
    float ao = 1.0 - saturate(totalOcclusion);

    return float4(ao, ao, ao, 1.0);
}

/**
 * Multi-scale GTAO with multiple radii for better quality
 */
float4 CalculateMultiScaleGTAO(
    float2 texcoord,
    int qualityLevel, // 0=low, 1=medium, 2=high, 3=ultra
    out float3 bentNormal
)
{
    // Adjust quality parameters based on level
    int numDirections = 4;
    int numScales = 1;

    switch (qualityLevel)
    {
        case 0: // Low
            numDirections = 4;
            numScales = 1;
            break;
        case 1: // Medium
            numDirections = 6;
            numScales = 2;
            break;
        case 2: // High
            numDirections = 8;
            numScales = 2;
            break;
        case 3: // Ultra
            numDirections = 12;
            numScales = 3;
            break;
    }

    float totalAO = 0.0;
    bentNormal = float3(0, 0, 0);

    // Sample multiple scales
    [loop]
    for (int scale = 0; scale < numScales; scale++)
    {
        float radiusScale = float(scale + 1) / float(numScales);

        float3 scaleBentNormal;
        float4 scaleAO = CalculateGTAO(
            texcoord,
            radiusScale,
            numDirections,
            scaleBentNormal
        );

        totalAO += scaleAO.r;
        bentNormal += scaleBentNormal;
    }

    // Average results
    totalAO /= float(numScales);
    bentNormal = SafeNormalize(bentNormal);

    return float4(totalAO, totalAO, totalAO, 1.0);
}

/**
 * Apply bilateral blur to AO for denoising while preserving edges
 */
float4 BilateralBlurAO(
    float2 texcoord,
    sampler2D aoTex,
    sampler2D depthTex,
    float blurRadius
)
{
    float centerDepth = tex2D(depthTex, texcoord).r;
    float centerAO = tex2D(aoTex, texcoord).r;

    if (IsSky(centerDepth))
        return float4(1, 1, 1, 1);

    float3 centerNormal = ReconstructNormal(texcoord);

    float totalAO = 0.0;
    float totalWeight = 0.0;

    const int kernelSize = 3;

    [loop]
    for (int by = -kernelSize; by <= kernelSize; by++)
    {
        [loop]
        for (int bx = -kernelSize; bx <= kernelSize; bx++)
        {
            float2 offset = float2(bx, by) * pixelsize * blurRadius;
            float2 sampleUV = texcoord + offset;

            if (any(sampleUV < 0) || any(sampleUV > 1))
                continue;

            float sampleDepth = tex2Dlod(depthTex, float4(sampleUV, 0, 0)).r;
            float sampleAO = tex2Dlod(aoTex, float4(sampleUV, 0, 0)).r;
            float3 sampleNormal = ReconstructNormalLod(sampleUV);

            // Calculate weights based on depth and normal similarity
            float depthWeight = exp(-abs(sampleDepth - centerDepth) * 10.0);
            float normalWeight = pow(max(0, dot(centerNormal, sampleNormal)), 4.0);
            float spatialWeight = exp(-float(bx*bx + by*by) / (2.0 * blurRadius * blurRadius));

            float weight = depthWeight * normalWeight * spatialWeight;

            totalAO += sampleAO * weight;
            totalWeight += weight;
        }
    }

    float blurredAO = totalWeight > 0 ? totalAO / totalWeight : centerAO;

    return float4(blurredAO, blurredAO, blurredAO, 1.0);
}

/**
 * Temporal accumulation for AO
 */
float4 TemporalAccumulateAO(
    float2 texcoord,
    float currentAO,
    sampler2D previousAOTex,
    sampler2D previousDepthTex,
    float blendFactor // 0.95-0.97 typical
)
{
    float currentDepth = SampleDepth(texcoord);

    // Estimate motion vector
    float2 motionVector = EstimateMotionVector(texcoord, currentDepth, previousDepthTex);
    float2 prevUV = texcoord + motionVector;

    // Check if reprojection is valid
    float previousDepth = tex2D(previousDepthTex, prevUV).r;
    
    // v1.1.2: Add normal validation
    float3 currentNormal = ReconstructNormal(texcoord);
    float3 previousNormal = ReconstructNormalFromBuffer(prevUV, previousDepthTex);
    
    bool validReprojection = IsReprojectionValid(prevUV, currentDepth, previousDepth, currentNormal, previousNormal);

    if (validReprojection)
    {
        float previousAO = tex2D(previousAOTex, prevUV).r;

        // Blend with history
        float blendedAO = lerp(currentAO, previousAO, blendFactor);

        // Clamp to prevent excessive ghosting
        // v1.1.1: Tightened from ±0.1 to ±0.04 to reduce ghosting on flat surfaces
        float aoMin = currentAO - 0.04;
        float aoMax = currentAO + 0.04;
        blendedAO = clamp(blendedAO, aoMin, aoMax);

        return float4(blendedAO, blendedAO, blendedAO, 1.0);
    }
    else
    {
        // No valid history, use current frame
        return float4(currentAO, currentAO, currentAO, 1.0);
    }
}

/**
 * Apply power curve to AO for artistic control
 */
float4 ApplyAOPower(float4 ao, float power)
{
    ao.rgb = pow(max(0.0, ao.rgb), power);
    return ao;
}

/**
 * Main entry point: High-quality GTAO with all features
 */
float4 ComputeAmbientOcclusion(
    float2 texcoord,
    int qualityLevel,
    float intensity,
    float power,
    out float3 bentNormal
)
{
    // Calculate multi-scale GTAO
    float4 ao = CalculateMultiScaleGTAO(texcoord, qualityLevel, bentNormal);

    // Apply intensity and power curve
    ao.rgb = lerp(float3(1, 1, 1), ao.rgb, intensity);
    ao = ApplyAOPower(ao, power);

    return ao;
}
