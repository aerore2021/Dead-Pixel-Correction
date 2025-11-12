#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
PNG to TXT Converter for FPGA Dead Pixel Correction Testbench
Converts PNG images to hexadecimal text files (one pixel per line)
"""

import os
import sys
from PIL import Image
import numpy as np

def png_to_txt(png_path, txt_path, bit_width=14):
    """
    Convert PNG image to TXT file with hexadecimal pixel values
    
    Args:
        png_path: Path to input PNG file
        txt_path: Path to output TXT file
        bit_width: Bit width for pixel values (default 14)
    """
    try:
        # Read PNG image
        img = Image.open(png_path)
        
        # Convert to grayscale if necessary
        if img.mode != 'L':
            img = img.convert('L')
        
        # Get image dimensions
        width, height = img.size
        print(f"Image dimensions: {width}x{height}")
        
        # Convert to numpy array
        img_array = np.array(img)
        
        # Calculate max value based on bit width
        max_val = (1 << bit_width) - 1
        
        # Scale pixel values to bit_width range
        # Assuming input is 8-bit (0-255)
        if bit_width != 8:
            img_array = (img_array.astype(np.float32) / 255.0 * max_val).astype(np.uint16)
        
        # Write to text file (one pixel per line in hex format)
        with open(txt_path, 'w') as f:
            for row in img_array:
                for pixel in row:
                    f.write(f'{pixel:04X}\n')
        
        print(f"Successfully converted {png_path} to {txt_path}")
        print(f"Total pixels: {width * height}")
        
    except Exception as e:
        print(f"Error converting {png_path}: {str(e)}")
        sys.exit(1)

def batch_convert(input_dir, output_dir=None, bit_width=14):
    """
    Batch convert all PNG files in a directory
    
    Args:
        input_dir: Directory containing PNG files
        output_dir: Directory for output TXT files (default: same as input_dir)
        bit_width: Bit width for pixel values
    """
    if output_dir is None:
        output_dir = input_dir
    
    # Create output directory if it doesn't exist
    os.makedirs(output_dir, exist_ok=True)
    
    # Find all PNG files
    png_files = [f for f in os.listdir(input_dir) if f.lower().endswith('.png')]
    
    if not png_files:
        print(f"No PNG files found in {input_dir}")
        return
    
    print(f"Found {len(png_files)} PNG file(s) in {input_dir}")
    
    # Convert each PNG file
    for png_file in png_files:
        png_path = os.path.join(input_dir, png_file)
        txt_file = os.path.splitext(png_file)[0] + '.txt'
        txt_path = os.path.join(output_dir, txt_file)
        
        print(f"\nConverting: {png_file}")
        png_to_txt(png_path, txt_path, bit_width)

if __name__ == '__main__':
    import argparse
    
    parser = argparse.ArgumentParser(description='Convert PNG images to TXT format for FPGA simulation')
    parser.add_argument('input', help='Input PNG file or directory')
    parser.add_argument('-o', '--output', help='Output TXT file or directory')
    parser.add_argument('-b', '--bits', type=int, default=14, help='Bit width for pixel values (default: 14)')
    parser.add_argument('-a', '--all', action='store_true', help='Convert all PNG files in directory')
    
    args = parser.parse_args()
    
    if args.all or os.path.isdir(args.input):
        # Batch conversion
        batch_convert(args.input, args.output, args.bits)
    else:
        # Single file conversion
        if args.output is None:
            args.output = os.path.splitext(args.input)[0] + '.txt'
        png_to_txt(args.input, args.output, args.bits)
