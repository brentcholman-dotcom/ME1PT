# ME1 Path Tracing - Quick Reference Card

**Version 1.0** | Keep this handy while playing!

---

## 🎮 Essential Controls

| Action | Key |
|--------|-----|
| Open ReShade Menu | **Home** |
| Toggle Shader On/Off | Click checkbox in ReShade |
| Reload Shaders | Click "Reload" button |
| Take Screenshot | **Print Screen** (ReShade) |

---

## ⚙️ Quick Settings (ReShade Menu → Home)

### Start Here
1. **Quality Preset**: Choose Low/Medium/High/Ultra
2. **Load Preset File**: Use Balanced.ini for best starting point
3. Adjust intensity sliders to taste

### Performance Slider Guide
```
Low Quality    = 10-20% FPS loss  (GTX 1060, RX 580)
Medium Quality = 20-30% FPS loss  (RTX 2060, RX 5700)
High Quality   = 30-50% FPS loss  (RTX 3070+, RX 6800+)
Ultra Quality  = 50%+ FPS loss    (RTX 4070+)
```

---

## 🎚️ Main Settings Quick Adjust

### Getting Best Visuals
```
GI Intensity:          1.0 - 1.2  (indirect lighting)
Reflection Intensity:  1.0 - 1.2  (mirrors/metal)
AO Intensity:          1.0 - 1.1  (shadows)
Temporal Blend:        0.95       (smoothness)
```

### Performance Boost
```
Quality Preset:        Low
GI Intensity:          0.8
Disable GI:            [unchecked] (biggest boost)
Max Ray Distance:      40-50
```

### Scene-Specific

**Indoor/Citadel:**
- GI Intensity: 1.0-1.2 (shows light bounce)
- Reflection Intensity: 0.8-1.0
- Max Ray Distance: 50-60

**Outdoor/Planets:**
- GI Intensity: 0.8-1.0
- Reflection Intensity: 1.0-1.2
- Max Ray Distance: 70-90

**Dark Areas:**
- GI Intensity: 1.2-1.5 (fills shadows)
- AO Intensity: 0.8 (less shadow)

**Combat (high motion):**
- Temporal Blend: 0.85 (less ghosting)
- Or disable Temporal Accumulation

---

## 🐛 Quick Fixes

| Problem | Solution |
|---------|----------|
| **Low FPS** | Lower Quality Preset → Disable GI → Use Performance.ini |
| **Flickering** | Check blue noise loaded → Increase Denoise Strength → Increase Temporal Blend |
| **Ghosting** | Reduce Temporal Blend Factor (0.85-0.90) |
| **No effect** | Check depth buffer enabled → Use debug modes → Reload shader |
| **Shader missing** | Verify files in Shaders folder → Click Reload → Check ReShade version 5.9+ |

---

## 🔧 Debug Modes

Press **Home** → Advanced/Debug → Debug Visualization:

| Mode | Shows | Use For |
|------|-------|---------|
| **Off** | Normal rendering | Gameplay |
| **Depth** | Depth buffer B&W | Check depth access |
| **Normals** | Surface directions | Verify geometry |
| **AO Only** | Shadows only | Tune AO settings |
| **GI Only** | Indirect light | Tune GI settings |
| **Reflections Only** | Mirrors only | Tune reflections |
| **Roughness** | Material smoothness | Debug material detection |

---

## 📋 Preset Comparison

| Setting | Performance | Balanced | Quality |
|---------|-------------|----------|---------|
| Ray Count (GI) | 4 | 8 | 12 |
| Ray Count (Refl) | 1-2 | 2-4 | 4-8 |
| March Steps | 48 | 64 | 96 |
| Bounces | 1 | 2 | 2-3 |
| Max Distance | 50 | 70 | 90 |
| FPS Impact | 10-20% | 20-30% | 30-50% |

---

## 💡 Pro Tips

### For Screenshots
1. Disable Temporal Accumulation (clean single frame)
2. Set Quality to Ultra
3. Use debug modes to show individual effects
4. Re-enable Temporal after screenshot

### For Videos/Streaming
1. Use Balanced preset (stable performance)
2. Keep Temporal on (smoother appearance)
3. Reduce Temporal Blend if camera moves fast (0.90)

### For Best Performance
1. Start with Performance.ini
2. Disable effects you don't need:
   - AO = small gain
   - Reflections = medium gain
   - GI = largest gain
3. Reduce Max Ray Distance: 30-40

### For Best Quality
1. Start with Quality.ini
2. Increase denoise strength for smoothness
3. Increase temporal blend for stability (0.97)
4. Let temporal accumulation settle (stand still 2-3 sec)

---

## 🎯 Recommended Settings by System

### GTX 1060 / RX 580
```ini
Quality Preset: Low
GI Intensity: 0.8
Reflection Intensity: 0.8
Enable Temporal: Yes
Temporal Blend: 0.90
Max Ray Distance: 40
```

### RTX 2060 / RX 5700
```ini
Quality Preset: Medium
GI Intensity: 1.0
Reflection Intensity: 1.0
Enable Temporal: Yes
Temporal Blend: 0.95
Max Ray Distance: 60
```

### RTX 3070+ / RX 6800+
```ini
Quality Preset: High
GI Intensity: 1.2
Reflection Intensity: 1.2
Enable Temporal: Yes
Temporal Blend: 0.97
Max Ray Distance: 80
```

### RTX 4070+ / RX 7800+
```ini
Quality Preset: Ultra
GI Intensity: 1.3
Reflection Intensity: 1.3
Enable Temporal: Yes
Temporal Blend: 0.98
Max Ray Distance: 100
```

---

## 📁 Installation Checklist

- [ ] ReShade 5.9.0+ installed to MassEffect1.exe
- [ ] All .fx and .fxh files in Shaders folder
- [ ] BlueNoise_256x256.png in Textures folder
- [ ] Preset file loaded (Balanced recommended)
- [ ] Shader enabled in ReShade menu
- [ ] Depth buffer access enabled
- [ ] FPS acceptable for your system

---

## 🔗 File Locations

**Game executable:**
```
[Install Path]\Game\ME1\Binaries\Win64\MassEffect1.exe
```

**ReShade Shaders folder:**
```
[Install Path]\Game\ME1\Binaries\Win64\reshade-shaders\Shaders\
```

**ReShade Textures folder:**
```
[Install Path]\Game\ME1\Binaries\Win64\reshade-shaders\Textures\
```

**ReShade config:**
```
[Install Path]\Game\ME1\Binaries\Win64\ReShade.ini
```

---

## 🆘 Emergency Reset

If shader causes problems:

1. **Disable shader**: Uncheck in ReShade menu
2. **Reset to defaults**: Delete ReShade.ini, restart game
3. **Remove completely**: Delete dxgi.dll or d3d11.dll from game folder
4. **Verify game**: Use Steam/EA App to verify files

---

## 📊 Performance Monitoring

### Check FPS
1. ReShade has built-in FPS counter (Settings → General)
2. Or use MSI Afterburner / RivaTuner

### Acceptable Performance
- 60 FPS base → 40-45 FPS with Quality preset = Good
- 60 FPS base → 50-54 FPS with Balanced = Great
- Below 30 FPS → Lower quality or disable effects

---

## 🎨 Visual Quality Expectations

### What You Should See
✅ Colored light bouncing between surfaces (GI)
✅ Reflections on armor, floors, metal
✅ Natural contact shadows in corners
✅ Enhanced depth and atmosphere
✅ Slight performance reduction

### What's Normal
✅ Slight ghosting during fast camera movement
✅ Reflections disappearing at screen edges
✅ Effects fading in over 1-2 seconds (temporal)
✅ Some noise in dark scenes

### What's Wrong (troubleshoot)
❌ Black screen or no visible change
❌ Severe flickering constantly
❌ Game crashes or freezes
❌ FPS drops to single digits
❌ Color/brightness completely wrong

---

**For detailed help**: See `Installation/README_INSTALLATION.md`

**Print this page and keep it next to your keyboard!**
