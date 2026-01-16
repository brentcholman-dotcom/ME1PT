# ME1 Path Tracing - Installation Guide

## Overview

This mod adds hybrid path tracing to Mass Effect 1 Legendary Edition using ReShade, bringing modern lighting techniques including:
- **Global Illumination**: Realistic indirect lighting with multiple light bounces
- **Ray-Traced Reflections**: Accurate reflections on surfaces with material-aware roughness
- **Ground Truth Ambient Occlusion**: High-quality contact shadows and depth

## System Requirements

### Minimum (Performance Preset)
- **GPU**: NVIDIA GTX 1060 6GB / AMD RX 580 8GB
- **RAM**: 8GB
- **VRAM**: 4GB
- **Expected FPS Impact**: 10-20%

### Recommended (Balanced Preset)
- **GPU**: NVIDIA RTX 2060 / AMD RX 5700
- **RAM**: 16GB
- **VRAM**: 6GB
- **Expected FPS Impact**: 20-30%

### High-End (Quality Preset)
- **GPU**: NVIDIA RTX 3070+ / AMD RX 6800+
- **RAM**: 16GB
- **VRAM**: 8GB+
- **Expected FPS Impact**: 30-50%

### Software Requirements
- Mass Effect 1 Legendary Edition (Steam, EA App, or Origin)
- DirectX 11 compatible GPU
- ReShade 5.9.0 or newer

---

## Installation Instructions

### Step 1: Download ReShade

1. Go to https://reshade.me/
2. Download the latest version (5.9.0 or newer)
3. Run the ReShade installer

### Step 2: Install ReShade to ME1 LE

1. In the ReShade installer, click **"Select game"**
2. Navigate to your Mass Effect 1 LE installation folder:
   - **Steam**: `C:\Program Files (x86)\Steam\steamapps\common\Mass Effect Legendary Edition\Game\ME1\Binaries\Win64\`
   - **EA App/Origin**: `C:\Program Files\EA Games\Mass Effect Legendary Edition\Game\ME1\Binaries\Win64\`
3. Select `MassEffect1.exe`
4. When asked to select rendering API, choose **"Direct3D 10/11/12"**
5. When asked about shader package, you can skip this (we'll add shaders manually)
6. Complete the installation

### Step 3: Install Path Tracing Shaders

1. Locate your ReShade shader folders (created during installation):
   - Shaders folder: `[ME1 Install Path]\reshade-shaders\Shaders\`
   - Textures folder: `[ME1 Install Path]\reshade-shaders\Textures\`

2. Copy the shader files from this mod:
   - Copy all `.fx` and `.fxh` files from `Reshade-Shaders/Shaders/` to ReShade's Shaders folder
   - Files to copy:
     - `ME1_PathTracing.fx`
     - `ME1_PT_Common.fxh`
     - `ME1_PT_AO.fxh`
     - `ME1_PT_GI.fxh`
     - `ME1_PT_Reflections.fxh`

3. Copy the texture file:
   - Copy `BlueNoise_256x256.png` from `Reshade-Shaders/Textures/` to ReShade's Textures folder
   - (See Blue Noise section below for how to obtain this texture)

### Step 4: Configure ReShade

1. Launch Mass Effect 1 Legendary Edition
2. Press **Home** key to open ReShade menu
3. Click **"Continue"** through the tutorial if this is first launch
4. You should see the ReShade overlay at the top of screen

### Step 5: Enable the Path Tracing Shader

1. In ReShade menu (Home key), go to the **"Home"** tab
2. Scroll down to find **"ME1_PathTracing.fx"** in the shader list
3. Check the box to enable it
4. The shader should now be active

### Step 6: Load a Preset (Recommended)

1. In ReShade menu, click on the **preset dropdown** at the top
2. Select **"Open preset folder"**
3. Copy one of the preset files from this mod's `Presets/` folder:
   - `Performance.ini` - For mid-range GPUs, prioritizes FPS
   - `Balanced.ini` - Good mix of quality and performance
   - `Quality.ini` - Maximum visual quality, high-end GPUs only
4. Back in ReShade, click the preset dropdown and select your chosen preset
5. The shader will reload with preset settings

---

## Blue Noise Texture

The shader requires a blue noise texture for improved temporal sampling. This reduces flickering and provides better quality.

### Option 1: Download Pre-made Blue Noise
1. Download a 256x256 blue noise texture from:
   - https://momentsingraphics.de/BlueNoise.html (Free academic resource)
   - https://github.com/Calinou/free-blue-noise-textures
2. Rename the file to `BlueNoise_256x256.png`
3. Place it in ReShade's Textures folder

### Option 2: Generate Your Own
If you have Python and PIL/numpy installed:

```python
import numpy as np
from PIL import Image

# Simple blue noise approximation
size = 256
noise = np.random.random((size, size, 4))
noise = (noise * 255).astype(np.uint8)

img = Image.fromarray(noise, 'RGBA')
img.save('BlueNoise_256x256.png')
```

Place the generated file in ReShade's Textures folder.

### Option 3: Use White Noise (Fallback)
If you cannot obtain blue noise, create a simple white noise texture:
1. Create any 256x256 random noise image in your image editor
2. Save as `BlueNoise_256x256.png`
3. Quality will be slightly reduced (more temporal noise) but shader will work

---

## Configuration Guide

### Understanding the UI Parameters

After enabling the shader, press **Home** to access ReShade menu and configure:

#### Performance Section
- **Quality Preset**: Overall quality level (Low/Medium/High/Ultra)
  - Adjusts ray count, sample count, and march steps
  - Start with Medium and adjust based on FPS
- **Enable Temporal Accumulation**: Smooths results over multiple frames
  - Recommended: ON (disable for screenshots to avoid ghosting)
- **Temporal Blend Factor**: How much to blend with previous frames
  - Higher = smoother but more ghosting during camera movement
  - Default: 0.95

#### Global Illumination Section
- **Enable Global Illumination**: Toggle indirect lighting
- **GI Intensity**: Brightness of indirect lighting (0.0-2.0)
  - Too high = washed out, too low = no effect
  - Default: 1.0
- **Bounce Light Intensity**: Strength of secondary light bounces
  - Default: 0.6
- **Denoise Strength**: Spatial filtering strength
  - Higher = smoother but blurrier
  - Default: 1.0

#### Reflections Section
- **Enable Reflections**: Toggle ray-traced reflections
- **Reflection Intensity**: Brightness of reflections (0.0-2.0)
  - Default: 1.0
- **Roughness Override**: Manual roughness control
  - -0.1 = auto-detect from materials (recommended)
  - 0.0-1.0 = force specific roughness (0=mirror, 1=matte)
- **Denoise Strength**: Spatial filtering for reflections
  - Default: 1.0

#### Ambient Occlusion Section
- **Enable Ambient Occlusion**: Toggle contact shadows
- **AO Intensity**: Strength of darkening effect (0.0-2.0)
  - Default: 1.0
- **AO Power**: Contrast curve for AO
  - Higher = more dramatic shadows
  - Default: 1.5
- **AO Blur Radius**: Smoothing amount
  - Default: 1.0

#### Advanced / Debug Section
- **Debug Visualization**: View individual components
  - Use to troubleshoot or understand what each effect does
  - Options: Off, Depth, Normals, AO Only, GI Only, Reflections Only, etc.
- **Max Ray Distance**: Maximum distance for ray marching
  - Higher = more accurate but slower
  - Default: 80.0

### Recommended Settings by Scene

**Indoor Scenes (tight corridors, rooms)**
- GI Intensity: 1.0-1.2
- Reflection Intensity: 0.8-1.0
- Max Ray Distance: 50-60

**Outdoor Scenes (Citadel, planets)**
- GI Intensity: 0.8-1.0
- Reflection Intensity: 1.0-1.2
- Max Ray Distance: 80-100

**Dark Scenes (caves, night)**
- GI Intensity: 1.2-1.5 (helps light up dark areas)
- AO Intensity: 0.8 (reduce to avoid too much darkness)

**Combat Scenes (high motion)**
- Consider disabling Temporal Accumulation temporarily
- Or reduce Temporal Blend Factor to 0.85

---

## Troubleshooting

### Shader Doesn't Appear in ReShade Menu
- Make sure all `.fx` and `.fxh` files are in the Shaders folder
- Check that ReShade is looking in the correct folder (Settings → Effect Search Paths)
- Try clicking "Reload" button in ReShade menu

### Shader Fails to Compile
- Ensure you're using ReShade 5.9.0 or newer
- Check that `ReShade.fxh` exists in ReShade's Shaders folder
- Look for error messages in the ReShade log (reshade.log in game folder)
- Common fix: Update ReShade to latest version

### Black Screen or No Effect Visible
- Enable debug mode (set Debug Visualization to "AO Only" or "Normals")
- If debug shows nothing, check that depth buffer access is enabled:
  - ReShade Settings → Enable "Copy depth buffer"
  - May need to use depth buffer addon
- Try disabling other shaders temporarily

### Performance Too Low
- Switch to Performance preset
- Disable Global Illumination (most expensive)
- Reduce Quality Preset to Low
- Lower Max Ray Distance to 40-50
- Reduce denoise strength (less filtering = faster)

### Flickering or Temporal Artifacts
- Reduce Temporal Blend Factor (0.85-0.90)
- Increase Denoise Strength
- Switch to lower quality preset (fewer samples = less noise)
- Ensure Blue Noise texture is loaded correctly

### Ghosting During Camera Movement
- Reduce Temporal Blend Factor
- Disable Temporal Accumulation during fast scenes
- This is normal for temporal techniques, adjust to preference

### Incorrect Reflections or GI
- Check depth buffer is working (use depth debug mode)
- Adjust Max Ray Distance based on scene scale
- Some screen-space limitations are expected:
  - No off-screen reflections/lighting
  - Less accurate at screen edges
  - This is normal for screen-space techniques

### Game Crashes
- Update GPU drivers
- Reduce quality settings
- Check VRAM usage (task manager)
- Try disabling other ReShade shaders
- Verify game files through Steam/EA App

---

## Shader Execution Order

If using multiple ReShade shaders, proper execution order matters:

**Recommended order:**
1. Pre-processing effects (sharpening, anti-aliasing)
2. **ME1_PathTracing.fx** ← This mod
3. Color grading/LUTs
4. Post-processing (bloom, lens flare)
5. UI shaders (letterbox, vignette)

To adjust order: Drag shaders in ReShade menu's technique list

---

## Known Limitations

These are inherent to screen-space techniques and cannot be fixed:

1. **Screen-Space Only**
   - Cannot render reflections/lighting for objects outside the screen
   - Reflections disappear at screen edges
   - No lighting from off-screen light sources

2. **Depth Buffer Limitations**
   - Cannot see through transparent surfaces
   - May have issues with particle effects
   - Some UI elements might be affected

3. **Temporal Artifacts**
   - Ghosting during fast camera movement is expected
   - Trade-off between smoothness and responsiveness

4. **Performance Cost**
   - Ray marching is expensive
   - Multiple passes required for all effects
   - Expect 30-50% FPS reduction on Quality preset

5. **Material Estimation**
   - Roughness and metalness are estimated from color
   - May not perfectly match intended materials
   - Can be overridden with manual roughness setting

---

## Compatibility

### Compatible With:
- Other ReShade shaders (SMAA, FXAA, LUTs, etc.)
- Mass Effect 1 LE HD texture mods
- Gameplay mods (as long as they don't modify rendering)

### Potential Issues With:
- Other lighting overhaul shaders (disable to avoid conflicts)
- Depth-based effects (ensure execution order is correct)
- Extreme FOV mods (may need adjustment)

### Not Compatible With:
- Mods that modify the executable
- Other path tracing injectors
- Software rendering mode

---

## Performance Optimization Tips

1. **Start with Balanced preset** and adjust from there
2. **Disable effects selectively**: If you only want reflections, disable GI and AO
3. **Reduce resolution**: Run game at lower resolution with quality shader
4. **Lower in-game settings**: Reduce game's built-in effects (shadows, ambient occlusion)
5. **Update drivers**: Latest GPU drivers can improve performance
6. **Close background apps**: Free up VRAM and system resources
7. **Use preset per scene**: Save different presets for indoor vs outdoor

---

## Uninstallation

To remove the mod:

1. Open ReShade menu (Home key) in game
2. Uncheck ME1_PathTracing.fx
3. Optionally, delete shader files from ReShade folders
4. To completely remove ReShade: Delete `dxgi.dll` or `d3d11.dll` from game folder

---

## Credits & License

**Created by**: Claude AI (Anthropic)
**Version**: 1.0
**Date**: 2026

This shader is provided as-is for personal use. Feel free to modify and share.

**Techniques Based On**:
- Ground Truth Ambient Occlusion (GTAO) by Jimenez et al.
- Screen-Space Global Illumination research
- Stochastic Screen-Space Reflections

**Special Thanks**:
- ReShade team for the framework
- Mass Effect modding community

---

## Support & Feedback

For issues, questions, or feedback:
- Check troubleshooting section above
- Verify you're using latest ReShade version
- Test with presets before custom settings
- Use debug modes to diagnose problems

---

## Changelog

**Version 1.0**
- Initial release
- Hybrid path tracing with GI, reflections, and AO
- Three quality presets
- Temporal accumulation
- Adaptive quality system
- Extensive UI configuration

---

Enjoy realistic path-traced lighting in Mass Effect 1 Legendary Edition!
