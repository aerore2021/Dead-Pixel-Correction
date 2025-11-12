#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Quick test script to verify PNG<->TXT conversion
"""

import os
import sys
from PIL import Image
import numpy as np

def test_conversion():
    """Test PNG to TXT and back to PNG conversion"""
    
    print("Testing PNG<->TXT conversion...")
    
    # Create a simple test image
    width, height = 640, 512
    test_img = np.random.randint(0, 256, (height, width), dtype=np.uint8)
    
    # Add some "bad pixels"
    bad_pixels = [(29, 156), (82, 132), (82, 133), (83, 132), (83, 133)]
    for row, col in bad_pixels:
        if row < height and col < width:
            test_img[row, col] = 0  # Set to black
    
    # Save as PNG
    test_png_path = 'test_image.png'
    img = Image.fromarray(test_img, mode='L')
    img.save(test_png_path)
    print(f"✓ Created test image: {test_png_path}")
    
    # Convert to TXT
    test_txt_path = 'test_image.txt'
    from png_to_txt import png_to_txt
    png_to_txt(test_png_path, test_txt_path, bit_width=14)
    print(f"✓ Converted to TXT: {test_txt_path}")
    
    # Check TXT file
    with open(test_txt_path, 'r') as f:
        lines = f.readlines()
    pixel_count = len([l for l in lines if l.strip()])
    expected = width * height
    
    if pixel_count == expected:
        print(f"✓ TXT file has correct pixel count: {pixel_count}")
    else:
        print(f"✗ TXT file pixel count mismatch: {pixel_count} != {expected}")
        return False
    
    # Convert back to PNG
    test_out_png_path = 'test_image_out.png'
    from txt_to_png import txt_to_png
    txt_to_png(test_txt_path, test_out_png_path, width, height, bit_width=14)
    print(f"✓ Converted back to PNG: {test_out_png_path}")
    
    # Verify images match
    img_orig = np.array(Image.open(test_png_path))
    img_out = np.array(Image.open(test_out_png_path))
    
    if img_orig.shape == img_out.shape:
        print(f"✓ Image dimensions match: {img_orig.shape}")
    else:
        print(f"✗ Image dimensions mismatch: {img_orig.shape} != {img_out.shape}")
        return False
    
    # Calculate difference
    max_diff = np.max(np.abs(img_orig.astype(int) - img_out.astype(int)))
    mean_diff = np.mean(np.abs(img_orig.astype(int) - img_out.astype(int)))
    
    print(f"  Max pixel difference: {max_diff}")
    print(f"  Mean pixel difference: {mean_diff:.2f}")
    
    if max_diff <= 1:  # Allow 1 LSB difference due to scaling
        print("✓ Images are equivalent (within tolerance)")
    else:
        print(f"✗ Images differ by more than 1 LSB")
        return False
    
    # Clean up
    os.remove(test_png_path)
    os.remove(test_txt_path)
    os.remove(test_out_png_path)
    print("\n✓ All tests passed!")
    
    return True

if __name__ == '__main__':
    success = test_conversion()
    sys.exit(0 if success else 1)
