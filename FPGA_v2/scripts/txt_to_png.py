#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
TXT to PNG Converter for FPGA Dead Pixel Correction Testbench
Converts hexadecimal text files (one pixel per line) to PNG images
"""

import os
import sys
from PIL import Image
import numpy as np

def txt_to_png(txt_path, png_path, width, height, bit_width=14):
    """
    Convert TXT file with hexadecimal pixel values to PNG image
    
    Args:
        txt_path: Path to input TXT file
        png_path: Path to output PNG file
        width: Image width in pixels
        height: Image height in pixels
        bit_width: Bit width of pixel values in TXT file (default 14)
    """
    try:
        # Read pixel values from text file
        pixels = []
        with open(txt_path, 'r') as f:
            for line in f:
                line = line.strip()
                if line:
                    # Parse hexadecimal value
                    try:
                        pixel_val = int(line, 16)
                        pixels.append(pixel_val)
                    except ValueError:
                        print(f"Warning: Invalid hex value: {line}")
                        continue
        
        # Check pixel count
        expected_pixels = width * height
        if len(pixels) != expected_pixels:
            print(f"Warning: Pixel count mismatch. Expected {expected_pixels}, got {len(pixels)}")
            # Pad or truncate if necessary
            if len(pixels) < expected_pixels:
                pixels.extend([0] * (expected_pixels - len(pixels)))
            else:
                pixels = pixels[:expected_pixels]
        
        # Convert to numpy array
        img_array = np.array(pixels, dtype=np.uint16).reshape((height, width))
        
        # Scale to 8-bit for PNG
        max_val = (1 << bit_width) - 1
        img_array_8bit = (img_array.astype(np.float32) / max_val * 255).astype(np.uint8)
        
        # Create and save image
        img = Image.fromarray(img_array_8bit, mode='L')
        img.save(png_path)
        
        print(f"Successfully converted {txt_path} to {png_path}")
        print(f"Image dimensions: {width}x{height}")
        print(f"Total pixels: {len(pixels)}")
        
    except Exception as e:
        print(f"Error converting {txt_path}: {str(e)}")
        sys.exit(1)

def batch_convert(input_dir, output_dir, width, height, bit_width=14):
    """
    Batch convert all TXT files in a directory
    
    Args:
        input_dir: Directory containing TXT files
        output_dir: Directory for output PNG files
        width: Image width in pixels
        height: Image height in pixels
        bit_width: Bit width of pixel values
    """
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Find all TXT files
    txt_files = [f for f in os.listdir(input_dir) if f.lower().endswith('.txt')]
    
    if not txt_files:
        print(f"No TXT files found in {input_dir}")
        return
    
    print(f"Found {len(txt_files)} TXT file(s) in {input_dir}")
    
    # Convert each TXT file
    for txt_file in txt_files:
        txt_path = os.path.join(input_dir, txt_file)
        png_file = os.path.splitext(txt_file)[0] + '_out.png'
        png_path = os.path.join(output_dir, png_file)
        
        print(f"\nConverting: {txt_file}")
        txt_to_png(txt_path, png_path, width, height, bit_width)

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Convert TXT format to PNG images after FPGA simulation')
    parser.add_argument('input', help='Input TXT file or directory')
    parser.add_argument('-o', '--output', help='Output PNG file or directory (required for batch conversion)')
    parser.add_argument('-w', '--width', type=int, required=True, help='Image width in pixels')
    parser.add_argument('-H', '--height', type=int, required=True, help='Image height in pixels')
    parser.add_argument('-b', '--bits', type=int, default=14, help='Bit width of pixel values (default: 14)')
    parser.add_argument('-a', '--all', action='store_true', help='Convert all TXT files in directory')
    
    args = parser.parse_args()
    
    if args.all or os.path.isdir(args.input):
        # Batch conversion
        if args.output is None:
            print("Error: Output directory must be specified for batch conversion")
            sys.exit(1)
        batch_convert(args.input, args.output, args.width, args.height, args.bits)
    else:
        # Single file conversion
        if args.output is None:
            args.output = os.path.splitext(args.input)[0] + '_out.png'
        txt_to_png(args.input, args.output, args.width, args.height, args.bits)
