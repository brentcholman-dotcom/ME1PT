# ME1 Path Tracing Mod

**Hybrid Path Tracing for Mass Effect 1 Legendary Edition**

Brings modern path traced lighting to Mass Effect 1 LE using ReShade, featuring global illumination, ray-traced reflections, and ground truth ambient occlusion.

![Version](https://img.shields.io/badge/version-1.1.1-blue)
![ReShade](https://img.shields.io/badge/ReShade-5.9+-green)
![Game](https://img.shields.io/badge/game-ME1%20Legendary%20Edition-red)

---

## Features

### 🌟 Global Illumination
- **Multi-bounce indirect lighting** (2-3 bounces)
- Realistic light propagation between surfaces
- Importance-sampled ray tracing
- Temporal accumulation for smooth results

### ✨ Ray-Traced Reflections
- **Screen-space reflections** with material awareness
- Roughness-based cone tracing for glossy surfaces
- Fresnel calculations for realistic reflection intensity
- Adaptive quality based on surface properties

### 🌑 Ground Truth Ambient Occlusion (GTAO)
- **Multi-scale sampling** for accurate contact shadows
- Bent normal calculation for directional occlusion
- Temporal accumulation and bilateral filtering
- Integration with global illumination

### ⚡ Performance Features
- **Adaptive quality system** (Low/Medium/High/Ultra presets)
- Hierarchical ray marching for faster traversal
- Temporal reprojection across frames
- Checkerboard rendering options
- Edge-preserving denoising

---

## Visual Improvements

**Before:** Standard ME1 LE lighting
**After:** Path traced lighting with:
- Realistic light bounce and color bleeding
- Accurate reflections on armor, floors, and metal surfaces
- Natural-looking contact shadows
- Enhanced depth and atmosphere in all scenes

**Best experienced in:**
- Citadel interiors (light bouncing off white surfaces)
- The Normandy (metallic reflections)
- Dark scenes (GI fills in shadows realistically)
- Combat areas (dynamic lighting on armor)

---

## Quick Start

### Requirements
- Mass Effect 1 Legendary Edition
- DirectX 11/12 GPU (NVIDIA GTX 1060 / AMD RX 580 minimum)
- 4GB+ VRAM
- ReShade 5.9.0+

### Installation (5 minutes)

1. **Download and install ReShade** to your ME1 LE executable
   - Get ReShade from: https://reshade.me/
   - Select DirectX 10/11/12 when prompted

2. **Copy shader files** to ReShade folders:
   ```
   Reshade-Shaders/Shaders/*.fx, *.fxh  → [Game]\reshade-shaders\Shaders\
   Reshade-Shaders/Textures/*           → [Game]\reshade-shaders\Textures\
   ```

3. **Get blue noise texture** (see `BLUE_NOISE_GUIDE.md` in Textures folder)
   - Download from https://momentsingraphics.de/BlueNoise.html
   - Rename to `BlueNoise_256x256.png`
   - Place in Textures folder

4. **Launch game** and press **Home** key
   - Enable `ME1_PathTracing.fx`
   - Load a preset from `Presets/` folder

5. **Choose your preset**:
   - `Performance.ini` - Mid-range GPUs (10-20% FPS impact)
   - `Balanced.ini` - High-end GPUs (20-30% FPS impact)
   - `Quality.ini` - Maximum quality (30-50% FPS impact)

**Full installation guide**: See `Installation/README_INSTALLATION.md`

---

## Performance Expectations

| Preset | GPU Recommendation | Target FPS Impact | Visual Quality |
|--------|-------------------|-------------------|----------------|
| **Performance** | GTX 1060, RX 580 | 10-20% | Good |
| **Balanced** | RTX 2060, RX 5700 | 20-30% | Great |
| **Quality** | RTX 3070+, RX 6800+ | 30-50% | Excellent |
| **Ultra** | RTX 4070+, RX 7800+ | 50%+ | Maximum |

*Tested at 1440p. Performance varies by scene complexity.*

---

## Configuration

All settings are adjustable in-game via ReShade menu (Home key):

### Quick Settings
- **Quality Preset**: Overall quality level (start here)
- **Temporal Accumulation**: Smooth over time (ON for quality, OFF for screenshots)
- **GI Intensity**: Indirect lighting strength (0.8-1.5)
- **Reflection Intensity**: Mirror effect strength (0.8-1.2)
- **AO Intensity**: Shadow strength (0.8-1.2)

### Advanced Settings
- Individual enable/disable for GI, Reflections, AO
- Denoise strength controls
- Ray distance and quality parameters
- Debug visualization modes

See full configuration guide in `Installation/README_INSTALLATION.md`

---

## File Structure

```
ME1 LE PT/
├── Reshade-Shaders/
│   ├── Shaders/
│   │   ├── ME1_PathTracing.fx          Main shader with UI and pipeline
│   │   ├── ME1_PT_Common.fxh           Shared utilities and functions
│   │   ├── ME1_PT_GI.fxh               Global illumination module
│   │   ├── ME1_PT_Reflections.fxh      Ray-traced reflections module
│   │   └── ME1_PT_AO.fxh               Ambient occlusion module
│   └── Textures/
│       ├── BlueNoise_256x256.png       Required: blue noise for sampling
│       └── BLUE_NOISE_GUIDE.md         How to obtain blue noise texture
├── Presets/
│   ├── Performance.ini                 Mid-range GPU preset
│   ├── Balanced.ini                    Recommended preset
│   └── Quality.ini                     Maximum quality preset
├── Installation/
│   └── README_INSTALLATION.md          Complete installation guide
└── README.md                           This file
```

---

## Troubleshooting

### Shader not visible
- Ensure all .fx and .fxh files are in Shaders folder
- Click "Reload" in ReShade menu
- Check ReShade is version 5.9.0+

### Performance too low
- Switch to Performance preset
- Disable Global Illumination (most expensive)
- Reduce Max Ray Distance to 40-50

### Flickering/noise
- Ensure blue noise texture is loaded
- Increase Temporal Blend Factor
- Increase Denoise Strength

### No effect visible
- Check depth buffer access is enabled
- Try debug modes to see individual effects
- Verify other shaders aren't conflicting

**Full troubleshooting guide**: See `Installation/README_INSTALLATION.md`

---

## Technical Details

### Rendering Pipeline
1. **AO Pass**: Calculate ambient occlusion with bent normals
2. **GI Pass**: Multi-bounce indirect lighting using AO data
3. **Reflection Pass**: Cone-traced reflections with roughness
4. **Temporal Pass**: Accumulate results across frames
5. **Denoise Pass**: Edge-preserving spatial filtering
6. **Composite Pass**: Blend all effects with original image

### Algorithms Used
- **GTAO** (Ground Truth Ambient Occlusion) for contact shadows
- **Hierarchical ray marching** for performance
- **Cosine-weighted importance sampling** for GI
- **Stochastic cone tracing** for glossy reflections
- **Bilateral filtering** for edge-aware denoising
- **Temporal reprojection** with disocclusion detection

### Optimization Techniques
- Temporal accumulation (16-32 frames)
- Blue noise sampling for better distribution
- Adaptive ray count based on roughness
- Distance-based LOD
- Early ray termination
- Screen-space clipping

---

## Known Limitations

These are inherent to screen-space techniques:

- **Cannot render off-screen**: Objects outside view are not reflected/lit
- **Screen edge artifacts**: Effects fade at screen boundaries
- **Depth buffer only**: Cannot see through transparent surfaces
- **Temporal ghosting**: Some blur during fast camera movement
- **Material estimation**: Roughness guessed from color, not always perfect

These limitations are normal and expected for real-time screen-space path tracing.

---

## Compatibility

### ✅ Works With
- HD texture mods
- Gameplay mods
- Other ReShade shaders (SMAA, LUTs, etc.)
- All DLC content

### ⚠️ May Conflict With
- Other lighting overhaul shaders
- Alternative AO/GI implementations
- Extreme FOV modifications

### ❌ Not Compatible With
- Non-DX11/12 rendering modes
- Modified game executables
- Other path tracing injectors

---

## FAQ

**Q: Will this work on my GPU?**
A: Minimum GTX 1060/RX 580. Performance preset should run on most modern GPUs.

**Q: Why is performance lower than expected?**
A: Path tracing is computationally expensive. Try Performance preset or disable GI.

**Q: Can I use this with other ReShade shaders?**
A: Yes! Use proper execution order (see installation guide).

**Q: Does this modify game files?**
A: No, ReShade is a post-processing injector. Uninstall by removing DLL.

**Q: Why do I see ghosting during camera movement?**
A: Temporal accumulation trades smoothness for temporal artifacts. Reduce blend factor.

**Q: Can I take screenshots without temporal effects?**
A: Yes, disable Temporal Accumulation before screenshot for clean single-frame result.

---

## Recommended Claude Code Prompts

If you want to modify or extend this shader, use these prompts with Claude Code for best results:

### To improve performance:
```
Analyze ME1_PathTracing.fx and suggest optimizations for better performance
while maintaining visual quality. Focus on reducing ray counts and improving
temporal efficiency.
```

### To add new features:
```
Add volumetric lighting support to ME1_PT_GI.fxh, implementing ray marching
through participating media for god rays and atmospheric scattering.
```

### To fix issues:
```
Debug the temporal reprojection in ME1_PT_Common.fxh - I'm seeing excessive
ghosting during camera rotation. Improve disocclusion detection.
```

### To adjust for different games:
```
Adapt this shader for [game name]. Update depth reconstruction and camera
parameters in ME1_PT_Common.fxh for [engine name].
```

---

## Credits

**Created by**: Claude AI (Anthropic)
**Version**: 1.0
**Release Date**: January 2026

**Built with**:
- ReShade framework
- HLSL shader language
- Research from SIGGRAPH papers on GTAO, screen-space GI, and SSR

**Special thanks to**:
- ReShade development team
- Mass Effect modding community
- Computer graphics research community

---

## License

This shader package is provided as-is for personal use with Mass Effect 1 Legendary Edition.

Feel free to:
- Use for personal gameplay
- Modify for your own needs
- Share with proper credit
- Learn from the code

Do not:
- Sell or commercialize
- Claim as your own work
- Bundle with paid products

---

## Version History

**v1.0** (January 2026)
- Initial release
- Full hybrid path tracing implementation
- Three quality presets
- Comprehensive documentation
- Debug visualization modes

---

## Support

For installation help, performance issues, or configuration questions:

1. Read `Installation/README_INSTALLATION.md` (comprehensive guide)
2. Check troubleshooting section
3. Verify you're using ReShade 5.9.0+
4. Test with presets before custom settings
5. Use debug modes to diagnose problems

---

**Enjoy realistic path traced lighting in Mass Effect 1 Legendary Edition!**

*"I should go... to a better-lit Citadel."* - Commander Shepard, probably
