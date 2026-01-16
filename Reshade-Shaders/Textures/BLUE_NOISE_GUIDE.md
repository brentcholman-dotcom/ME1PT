# Blue Noise Texture Guide

The path tracing shader requires a blue noise texture for optimal temporal sampling and noise reduction. This guide provides multiple methods to obtain this texture.

## What is Blue Noise?

Blue noise is a type of noise pattern where samples are evenly distributed but random. Unlike white noise (purely random) or ordered patterns (regular grid), blue noise:
- Reduces visible patterns and banding
- Minimizes temporal flickering
- Improves convergence for path tracing
- Provides better perceived quality with fewer samples

## Required Specifications

- **Filename**: `BlueNoise_256x256.png`
- **Resolution**: 256x256 pixels
- **Format**: PNG (RGBA or RGB)
- **Bit Depth**: 8-bit per channel is sufficient
- **Location**: Place in ReShade's Textures folder

---

## Method 1: Download Pre-made Blue Noise (Recommended)

### Option A: Moments in Graphics (Academic Resource)
1. Visit: https://momentsingraphics.de/BlueNoise.html
2. Download "LDR RGBA" or "HDR RGB" blue noise textures
3. Choose 256x256 size if available, or download larger and resize
4. Rename to `BlueNoise_256x256.png`
5. Place in ReShade Textures folder

**Pros**: High quality, scientifically generated
**Cons**: Requires download and potentially resizing

### Option B: Free Blue Noise Textures (GitHub)
1. Visit: https://github.com/Calinou/free-blue-noise-textures
2. Download repository or specific textures
3. Look for 256x256 PNG files
4. Rename to `BlueNoise_256x256.png`
5. Place in ReShade Textures folder

**Pros**: Free, variety available, no registration
**Cons**: May need to resize or convert format

### Option C: Christoph Peters' Blue Noise
1. Visit: https://www.arnoldrenderer.com/research/dither_abstract.htm
2. Or search for "Christoph Peters blue noise textures"
3. Download appropriate texture pack
4. Extract and rename suitable texture

**Pros**: Very high quality, optimized for rendering
**Cons**: Larger download, may need processing

---

## Method 2: Generate Using Python

If you have Python installed with PIL (Pillow) and NumPy:

### Simple Blue Noise Approximation

```python
import numpy as np
from PIL import Image

def generate_blue_noise_approx(size=256):
    """
    Approximation of blue noise using high-pass filtering
    Not perfect but works well for path tracing
    """
    # Start with white noise
    white_noise = np.random.random((size, size))

    # Apply simple high-pass filter to push energy to high frequencies
    from scipy.ndimage import gaussian_filter
    low_freq = gaussian_filter(white_noise, sigma=4.0)
    high_freq = white_noise - low_freq

    # Normalize
    blue_noise = (high_freq - high_freq.min()) / (high_freq.max() - high_freq.min())

    # Convert to RGBA
    blue_noise_rgba = np.stack([blue_noise] * 4, axis=2)
    blue_noise_rgba[:, :, 3] = 1.0  # Full alpha
    blue_noise_rgba = (blue_noise_rgba * 255).astype(np.uint8)

    return Image.fromarray(blue_noise_rgba, 'RGBA')

# Generate and save
img = generate_blue_noise_approx(256)
img.save('BlueNoise_256x256.png')
print("Blue noise texture generated: BlueNoise_256x256.png")
```

**Requirements**: `pip install pillow numpy scipy`

### Void-and-Cluster Algorithm (Better Quality)

```python
import numpy as np
from PIL import Image

def void_and_cluster(size=256, iterations=100):
    """
    Basic void-and-cluster algorithm for blue noise generation
    More accurate than filtering approach
    """
    pattern = np.zeros((size, size))
    n_samples = size * size // 2

    # Initial random samples
    samples = []
    for _ in range(n_samples):
        # Find largest void
        if len(samples) == 0:
            x, y = size // 2, size // 2
        else:
            # Simple approach: random with some spreading
            x = np.random.randint(0, size)
            y = np.random.randint(0, size)

            # Check distance to existing samples
            while pattern[y, x] > 0:
                x = np.random.randint(0, size)
                y = np.random.randint(0, size)

        pattern[y, x] = 1
        samples.append((x, y))

    # Normalize
    pattern = pattern / pattern.max() if pattern.max() > 0 else pattern

    # Convert to RGBA
    pattern_rgba = np.stack([pattern] * 4, axis=2)
    pattern_rgba[:, :, 3] = 1.0
    pattern_rgba = (pattern_rgba * 255).astype(np.uint8)

    return Image.fromarray(pattern_rgba, 'RGBA')

# Generate and save
img = void_and_cluster(256)
img.save('BlueNoise_256x256.png')
print("Blue noise texture generated: BlueNoise_256x256.png")
```

---

## Method 3: Use Photoshop/GIMP

### In Photoshop:
1. Create new image: 256x256 pixels
2. Fill with 50% gray
3. Filter → Noise → Add Noise (Amount: 100%, Gaussian, Monochromatic)
4. Filter → Blur → Gaussian Blur (Radius: 0.5-1.0 px)
5. Image → Adjustments → High Pass (Radius: 10-15 px)
6. Adjust levels to full 0-255 range
7. Save as PNG: `BlueNoise_256x256.png`

### In GIMP:
1. File → New Image: 256x256
2. Filters → Render → Noise → RGB Noise (all channels, 0.8-1.0)
3. Filters → Blur → Gaussian Blur (1-2 px)
4. Filters → Enhance → High Pass (15-20 px)
5. Colors → Auto → Normalize
6. Export as PNG: `BlueNoise_256x256.png`

**Pros**: No programming required, visual control
**Cons**: Not true blue noise, approximation only

---

## Method 4: Quick Fallback (White Noise)

If you cannot obtain blue noise immediately, use simple white noise as fallback:

### Python One-liner:
```python
import numpy as np
from PIL import Image

noise = np.random.random((256, 256, 4)) * 255
Image.fromarray(noise.astype(np.uint8), 'RGBA').save('BlueNoise_256x256.png')
```

### Or any image editor:
1. Create 256x256 image
2. Apply RGB Noise filter at maximum strength
3. Save as `BlueNoise_256x256.png`

**Note**: This will work but with slightly more visible noise/flickering in the shader. Quality difference is small for most users.

---

## Verification

After placing the texture, verify it's working:

1. Launch game with ReShade
2. Enable ME1_PathTracing shader
3. Open ReShade menu (Home key)
4. Check ReShade log for texture loading errors
5. If GI/Reflections have severe flickering, texture might not be loading

### Common Issues:

**Texture not loading:**
- Check filename is exactly `BlueNoise_256x256.png` (case-sensitive)
- Verify it's in correct Textures folder
- Check ReShade texture search paths in settings
- Try PNG-8 or PNG-24 format

**Still flickering with blue noise:**
- Normal for first few frames (temporal accumulation needs time)
- Increase Temporal Blend Factor
- Increase Denoise Strength
- Ensure texture is actual blue noise, not pure white noise

---

## Texture Quality Comparison

**True Blue Noise** (Methods 1, 2 with void-and-cluster):
- Best temporal stability
- Least visible patterns
- Fastest convergence
- Recommended for Quality preset

**Approximated Blue Noise** (Method 2 simple, Method 3):
- Good temporal stability
- Slight patterns may be visible
- Good for Balanced/Performance presets

**White Noise** (Method 4):
- Acceptable for performance testing
- More flickering/noise visible
- Use only as temporary fallback

---

## Advanced: Creating Tileable Blue Noise

For even better temporal distribution, create tileable blue noise:

```python
import numpy as np
from PIL import Image

def make_tileable(img_array):
    """Make an image tileable by blending edges"""
    size = img_array.shape[0]

    # Create blending weights
    x = np.arange(size)
    y = np.arange(size)
    X, Y = np.meshgrid(x, y)

    # Distance from edges
    dist_x = np.minimum(X, size - X) / (size / 2)
    dist_y = np.minimum(Y, size - Y) / (size / 2)
    weight = np.minimum(dist_x, dist_y)

    # Blend with tiled version
    tiled = np.roll(np.roll(img_array, size // 2, axis=0), size // 2, axis=1)
    blended = img_array * weight[:, :, np.newaxis] + tiled * (1 - weight[:, :, np.newaxis])

    return blended

# Use with any generation method above
```

---

## Recommended Approach

**For best results (in order of preference):**

1. Download from Moments in Graphics (highest quality)
2. Use GitHub free textures (easiest)
3. Generate with Python void-and-cluster (if comfortable with code)
4. Create in image editor (if no programming)
5. White noise fallback (temporary only)

**Time investment vs Quality:**
- Method 1: 5 minutes, best quality
- Method 2: 10 minutes (if Python installed), excellent quality
- Method 3: 15 minutes, good quality
- Method 4: 2 minutes, acceptable quality

---

## License Considerations

When downloading pre-made blue noise:
- Academic resources (Moments in Graphics): Usually free for research/personal use
- GitHub repositories: Check LICENSE file
- Creating your own: No restrictions

For this Mass Effect mod (personal use), all methods are acceptable.

---

## Need Help?

If you're having trouble:
1. Try the white noise fallback first to test if shader works
2. Check ReShade log file (reshade.log) for texture loading errors
3. Verify folder paths are correct
4. Ensure PNG format is compatible (try converting to PNG-8)

The shader will still work without perfect blue noise - it just won't look as smooth temporally.

---

Place your final `BlueNoise_256x256.png` in:
```
[Mass Effect 1 LE Install]\reshade-shaders\Textures\BlueNoise_256x256.png
```

Then reload the shader in ReShade menu!
