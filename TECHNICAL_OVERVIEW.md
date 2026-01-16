# ME1 Path Tracing - Technical Overview

This document provides a technical overview of the shader implementation for developers, modders, and anyone interested in understanding how the path tracing works.

---

## Architecture Overview

### Modular Design

The shader is split into multiple modules for maintainability and clarity:

```
ME1_PathTracing.fx          ← Main shader (integration, UI, pipeline)
    ↓ includes
ME1_PT_Common.fxh          ← Shared utilities (depth, normals, sampling)
ME1_PT_AO.fxh              ← Ambient occlusion (GTAO algorithm)
ME1_PT_GI.fxh              ← Global illumination (multi-bounce)
ME1_PT_Reflections.fxh     ← Screen-space reflections (cone tracing)
```

### Pipeline Flow

```
Original Frame
    ↓
[Pass 1] Calculate AO
    ↓ texAO
[Pass 2] Blur AO (bilateral)
    ↓ texAOBlurred
[Pass 3] Temporal AO
    ↓ texAOBlurred (updated)
[Pass 4] Calculate GI (uses AO + bent normals)
    ↓ texGI
[Pass 5] Denoise GI (bilateral)
    ↓ texGIDenoised
[Pass 6] Temporal GI
    ↓ texGIDenoised (updated)
[Pass 7] Calculate Reflections
    ↓ texReflection
[Pass 8] Denoise Reflections
    ↓ texReflectionDenoised
[Pass 9] Temporal Reflections
    ↓ texReflectionDenoised (updated)
[Pass 10] Composite (AO × Original + GI + Reflections)
    ↓ Final Output
[Pass 11-14] Store previous frame data (depth, AO, GI, reflections)
    ↓ For next frame's temporal accumulation
```

### Render Targets

| Texture | Format | Purpose | Size |
|---------|--------|---------|------|
| texAO | R8 | Raw AO values | Full res |
| texAOBlurred | R8 | Denoised AO | Full res |
| texPreviousAO | R8 | Previous frame AO | Full res |
| texGI | RGBA16F | Raw GI lighting | Full res |
| texGIDenoised | RGBA16F | Denoised GI | Full res |
| texPreviousGI | RGBA16F | Previous frame GI | Full res |
| texReflection | RGBA16F | Raw reflections | Full res |
| texReflectionDenoised | RGBA16F | Denoised reflections | Full res |
| texPreviousReflection | RGBA16F | Previous frame reflections | Full res |
| texPreviousDepth | R32F | Previous frame depth | Full res |

**VRAM Usage** (at 1920×1080):
- Depth buffers: ~8 MB
- AO buffers: ~6 MB
- GI buffers: ~48 MB
- Reflection buffers: ~48 MB
- **Total**: ~110 MB additional VRAM

---

## Module Breakdown

### ME1_PT_Common.fxh

**Purpose**: Shared utilities used by all modules

**Key Functions**:

```hlsl
// Depth & Position Reconstruction
float SampleDepth(float2 texcoord)
float LinearizeDepth(float depth)
float3 GetViewPosition(float2 texcoord, float depth)

// Normal Reconstruction
float3 ReconstructNormal(float2 texcoord)
float3 ReconstructNormalImproved(float2 texcoord)  // Better edge handling

// Temporal Reprojection
float2 EstimateMotionVector(float2 texcoord, float currentDepth, sampler2D prevDepth)
bool IsReprojectionValid(float2 prevUV, float currentDepth, float previousDepth)

// Blue Noise Sampling
float4 SampleBlueNoise(float2 texcoord)
float2 GetBlueNoiseOffset(float2 texcoord, int sampleIndex)
float3 CosineSampleHemisphere(float2 u, float3 normal)

// Material Estimation
float EstimateRoughness(float2 texcoord, sampler2D colorTex)
float EstimateMetalness(float3 color)
float3 EstimateF0(float3 color, float metalness)

// BRDF & Fresnel
float3 FresnelSchlick(float cosTheta, float3 F0)
float DistributionGGX(float3 N, float3 H, float roughness)

// Ray Marching
float4 ScreenSpaceRayMarch(float3 origin, float3 dir, int maxSteps, ...)
```

**Depth Reconstruction**:
- Converts ReShade's linearized depth to view-space
- Reconstructs 3D position from depth + UV
- Handles `RESHADE_DEPTH_INPUT_IS_UPSIDE_DOWN`

**Normal Reconstruction**:
- Uses depth derivatives to compute surface normals
- Improved version uses 3x3 kernel for robustness
- Handles depth discontinuities at edges

**Blue Noise**:
- Tiles 256×256 texture across screen
- Adds temporal rotation using golden ratio
- Provides low-discrepancy samples for ray generation

---

### ME1_PT_AO.fxh

**Purpose**: Ground Truth Ambient Occlusion

**Algorithm**: GTAO (Jimenez et al.)

**Key Concepts**:
1. **Horizon Angles**: For each direction, find horizon angle where geometry occludes the hemisphere
2. **Integration**: Integrate occlusion across multiple directions
3. **Bent Normals**: Calculate average unoccluded direction
4. **Multi-Scale**: Sample at multiple radii for better quality

**Main Functions**:

```hlsl
float CalculateHorizonAngle(...)       // Find horizon in one direction
float IntegrateOcclusionSlice(...)     // Integrate single direction
float4 CalculateGTAO(...)              // Full GTAO calculation
float4 CalculateMultiScaleGTAO(...)    // With multiple radii
float4 BilateralBlurAO(...)            // Edge-preserving denoise
float4 TemporalAccumulateAO(...)       // Temporal smoothing
```

**Quality Levels**:
- Low: 4 directions, 1 scale
- Medium: 6 directions, 2 scales
- High: 8 directions, 2 scales
- Ultra: 12 directions, 3 scales

**Performance**: ~15-20% of total cost

**Output**:
- `.rgb`: AO value (1 = no occlusion, 0 = full occlusion)
- Bent normal stored separately for GI use

---

### ME1_PT_GI.fxh

**Purpose**: Multi-bounce global illumination

**Algorithm**: Temporal screen-space GI with importance sampling

**Key Concepts**:
1. **Hierarchical Ray March**: Adaptive step size, faster convergence
2. **Importance Sampling**: Use bent normals from AO to bias sampling
3. **Multi-Bounce**: Recursively gather indirect light (2-3 bounces)
4. **Energy Conservation**: Each bounce loses energy (×0.6 per bounce)
5. **Temporal Accumulation**: Average over 16-32 frames

**Main Functions**:

```hlsl
float4 HierarchicalRayMarch(...)         // Adaptive ray marching
float3 CalculateIndirectLightingBounce(...) // Single bounce
float3 CalculateGlobalIllumination(...)  // Multi-bounce integration
float3 TemporalAccumulateGI(...)         // Temporal smoothing
float3 DenoiseGI(...)                    // Spatial filtering
```

**Ray Marching**:
```
Start with small steps
    If ray behind surface: reduce step size, back up
    If ray in front: increase step size
    If intersection: binary search refinement
Stop at: hit, max distance, or screen edge
```

**Quality Levels**:
- Low: 4 rays, 1 bounce, 30m distance
- Medium: 8 rays, 2 bounces, 50m distance
- High: 12 rays, 2 bounces, 70m distance
- Ultra: 16 rays, 3 bounces, 100m distance

**Performance**: ~40-50% of total cost (most expensive)

**Output**: RGB indirect lighting to be added to scene

---

### ME1_PT_Reflections.fxh

**Purpose**: Ray-traced screen-space reflections

**Algorithm**: Stochastic cone tracing with material awareness

**Key Concepts**:
1. **Reflection Direction**: Mirror reflection from view and normal
2. **Cone Tracing**: For rough surfaces, sample within cone
3. **Roughness Adaptation**: Smoother = fewer samples, sharper cone
4. **Binary Search**: Refine hit location for accuracy
5. **Fresnel**: Physically-based reflection intensity

**Main Functions**:

```hlsl
float4 RayMarchReflection(...)          // Single high-quality ray
float4 ConeTraceReflection(...)         // Multiple rays in cone
float4 CalculateReflection(...)         // Main entry point
float4 TemporalAccumulateReflection(...) // Temporal smoothing
float4 DenoiseReflection(...)           // Spatial filtering
```

**Cone Tracing**:
```
Cone angle = roughness × 45°
Sample N rays within cone using cosine distribution
Weight by distance from cone axis
Blend based on confidence
```

**Quality Levels**:
- Low: 1-2 samples, 48 steps, 40m
- Medium: 2-4 samples, 64 steps, 60m
- High: 4-8 samples, 96 steps, 75m
- Ultra: 8-16 samples, 128 steps, 100m

**Performance**: ~30-35% of total cost

**Output**:
- `.rgb`: Reflection color
- `.a`: Confidence (0 = no hit, 1 = perfect hit)

---

## Advanced Techniques

### Temporal Accumulation

**Goal**: Average results over multiple frames to reduce noise

**Method**:
```hlsl
blendedResult = lerp(currentFrame, previousFrame, blendFactor)
// blendFactor typically 0.95-0.97
```

**Challenges**:
1. **Motion**: Objects and camera move, previous samples invalid
2. **Disocclusion**: New geometry appears, no valid history

**Solutions**:
- Estimate motion vectors from depth buffer
- Detect disocclusion by comparing depths
- Clamp blended result to prevent ghosting
- Reduce blend factor during high motion

**Implementation**:
```hlsl
float2 EstimateMotionVector(...)
{
    // Search for matching depth in previous frame
    // Simple but effective for most cases
    for each neighbor:
        if depth_match is better:
            store offset
    return best offset
}

bool IsReprojectionValid(...)
{
    if outside_screen: return false
    if depth_mismatch > threshold: return false  // Disocclusion
    return true
}
```

### Denoising

**Goal**: Reduce noise while preserving edges

**Method**: Bilateral filtering (spatial + range)

```hlsl
weight = depth_weight × normal_weight × spatial_weight
depth_weight = exp(-|depth_diff| × sensitivity)
normal_weight = pow(dot(normal1, normal2), power)
spatial_weight = gaussian(distance)
```

**Adaptive Kernel**:
- High variance → larger blur kernel
- Low confidence → more blur
- Edge proximity → smaller kernel

**Per-Effect Tuning**:
- AO: Moderate blur (1.0-1.5)
- GI: Light blur (0.8-1.2) - preserve color detail
- Reflections: Heavy blur (1.0-2.0) - very noisy raw

### Importance Sampling

**Goal**: Place samples where they matter most

**For GI**:
- Use bent normals from AO (points towards unoccluded directions)
- Cosine-weighted hemisphere (Lambert BRDF)
- Blue noise for even distribution

```hlsl
float3 samplingNormal = lerp(geometricNormal, bentNormal, 0.5)
float3 rayDir = CosineSampleHemisphere(blueNoiseUV, samplingNormal)
// Automatically weighted by cos(θ) in sampling
```

**For Reflections**:
- Cone angle based on roughness
- Hammersley sequence for low-discrepancy
- Blue noise offset for temporal variation

### Material Estimation

**Challenge**: ReShade only has color + depth, no material data

**Roughness Estimation**:
```hlsl
// High-frequency detail → rough surface
// Smooth color → smooth surface
variance = average(|neighbor_color - center_color|)
roughness = saturate(variance × scale)
```

**Metalness Estimation**:
```hlsl
// Metallic surfaces: saturated color, not too dark
saturation = (max_channel - min_channel) / max_channel
brightness = average(rgb)
metalness = saturation × smoothstep(0.2, 0.8, brightness)
```

**Limitations**:
- Not always accurate (painted metal looks non-metallic)
- Can be overridden with manual roughness parameter

---

## Performance Optimization Strategies

### 1. Hierarchical Ray Marching

Instead of fixed step size:
```hlsl
if ray_behind_surface:
    step_size *= 0.5  // Refine
    back_up()
else if ray_far_from_surface:
    step_size *= 1.5  // Skip ahead
```

Saves ~30% ray march time.

### 2. Early Ray Termination

```hlsl
if hit_confidence > threshold:
    break  // Don't keep marching
if distance > max_distance:
    break
if outside_screen_bounds:
    break
```

### 3. Checkerboard Rendering (Future)

Render expensive passes at half resolution in checkerboard pattern:
```
Frame 1: X . X . X .
         . . . . . .
         X . X . X .

Frame 2: . X . X . X
         . . . . . .
         . X . X . X
```

Reconstruct with temporal reprojection. Can give 2× performance.

### 4. Distance-based LOD

```hlsl
float distanceFactor = saturate(depth / far_plane)
int rayCount = lerp(max_rays, min_rays, distanceFactor)
// Far objects get fewer rays
```

### 5. Adaptive Quality

```hlsl
float motion = length(motionVector)
if motion > threshold:
    reduce ray_count  // Less visible during motion
    reduce temporal_blend  // Respond faster
```

### 6. Texture Fetch Optimization

```hlsl
// Use point sampling for depth/normals
tex2Dfetch(sampler, int2(uv * screen_size))
// Faster than tex2D with filtering
```

---

## Known Issues and Limitations

### Screen-Space Limitations

**Problem**: Cannot see beyond screen
**Impact**:
- Reflections cut off at edges
- No lighting from off-screen sources
- Wrong in some cases

**Mitigation**:
- Fade effects at screen edges
- Reduce confidence near boundaries
- Accept as limitation of technique

### Depth Buffer Precision

**Problem**: Depth buffer has limited precision
**Impact**:
- False intersections (z-fighting)
- Missed intersections (holes)
- Temporal instability

**Mitigation**:
- Thickness parameter for hit detection
- Binary search refinement
- Temporal averaging

### Temporal Ghosting

**Problem**: Blending with old frames causes trails
**Impact**: Visible during camera movement

**Solutions**:
- Reduce blend factor (trades noise for ghosting)
- Better motion estimation
- Adaptive blending based on motion
- User can disable temporal for screenshots

### Performance Cost

**Problem**: Path tracing is expensive
**Impact**: 30-50% FPS reduction

**Why**:
- Multiple full-screen passes (14 passes total)
- Ray marching is O(n × m) per pixel
- Large render targets (RGBA16F)

**Mitigation**:
- Quality presets scale ray counts
- User can disable expensive effects
- Temporal amortizes cost over frames

---

## Extending the Shader

### Adding New Effects

To add a new effect (e.g., subsurface scattering):

1. **Create module**: `ME1_PT_SSS.fxh`
2. **Add functions**: Implement algorithm
3. **Add to main shader**: Include and integrate
4. **Add textures**: If needed for intermediate storage
5. **Add UI parameters**: Expose controls
6. **Add to pipeline**: Insert pass in correct order

Example structure:
```hlsl
// ME1_PT_SSS.fxh
#pragma once
#include "ME1_PT_Common.fxh"

float3 CalculateSSS(float2 texcoord, ...)
{
    // Implementation
}
```

### Porting to Other Games

To adapt for another game:

1. **Update depth reconstruction** in Common.fxh:
   - Adjust projection matrix parameters
   - Update far/near plane values
   - Test with debug visualization

2. **Adjust scene scale** in all modules:
   - Max ray distance
   - AO radius
   - Thickness parameters

3. **Test and tune**:
   - Different engines may need different values
   - Material estimation may behave differently

### Performance Profiling

To find bottlenecks:

1. **Disable passes one by one**: See which costs most
2. **Reduce quality**: If perf improves, ray count is issue
3. **Reduce resolution**: If perf improves, fill rate is issue
4. **Use GPU profiler**: RenderDoc, NSight, etc.

---

## Mathematical Details

### GTAO Integration

The GTAO integral approximates visibility:

```
AO = (1/π) ∫∫ V(ω) cos(θ) dω

Approximation:
AO ≈ (1/4π) Σ[(sinθ₊ - sinθ₋) + (θ₊ - θ₋)]
```

Where θ₊ and θ₋ are horizon angles in positive and negative directions.

### Cosine-Weighted Sampling

For Lambertian surfaces, sample PDF = cos(θ)/π:

```
φ = 2π × ξ₁
θ = arcsin(√ξ₂)

Where ξ₁, ξ₂ are uniform random [0,1]
```

This automatically weights samples by cos(θ), no additional weighting needed.

### Fresnel Schlick Approximation

```
F(θ) = F₀ + (1 - F₀)(1 - cos(θ))⁵

F₀ = ((n₁ - n₂)/(n₁ + n₂))²

For dielectrics: F₀ ≈ 0.04
For metals: F₀ = albedo
```

---

## Debugging Tips

### Shader Won't Compile

1. Check ReShade version (5.9.0+)
2. Look at `reshade.log` for errors
3. Verify all includes are present
4. Check for syntax errors in modifications

### No Visual Effect

1. Use debug modes to check each component
2. Verify depth buffer access (debug mode: Depth)
3. Check normals look correct (debug mode: Normals)
4. Ensure textures are loading (check log)

### Poor Performance

1. Start with Performance preset
2. Disable GI (most expensive)
3. Reduce max ray distance
4. Check VRAM usage (may be swapping)

### Visual Artifacts

1. **Flickering**: Check blue noise, increase denoise
2. **Ghosting**: Reduce temporal blend factor
3. **Black spots**: Increase thickness parameter
4. **Edge issues**: Normal, screen-space limitation
5. **Wrong colors**: Check if other shaders conflict

---

## References

**Papers & Research**:
- Jimenez et al., "Practical Realtime Strategies for Accurate Indirect Occlusion" (GTAO)
- Stachowiak, "Stochastic Screen-Space Reflections" (SSR)
- McGuire & Mara, "Efficient GPU Screen-Space Ray Tracing" (Ray marching)

**Resources**:
- ReShade Documentation: https://reshade.me/
- HLSL Reference: Microsoft Docs
- Real-Time Rendering: https://www.realtimerendering.com/

---

## Contact & Contributing

This shader is open for modification and improvement.

**Ideas for contributions**:
- Performance optimizations
- Better material estimation
- Checkerboard rendering implementation
- Motion vector improvements
- Game-specific optimizations

When modifying, please:
- Maintain code comments
- Test thoroughly
- Update documentation
- Share improvements with community

---

**End of Technical Overview**

For user documentation, see `README.md` and `Installation/README_INSTALLATION.md`.
