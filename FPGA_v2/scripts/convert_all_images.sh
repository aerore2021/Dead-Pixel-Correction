#!/bin/bash
# Batch convert all test images from PNG to TXT format

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
IMAGE_DIR="${SCRIPT_DIR}/../image_inputs"
CONVERTER="${SCRIPT_DIR}/png_to_txt.py"

echo "==========================================="
echo "  Converting PNG Images to TXT Format"
echo "==========================================="

# Check if converter exists
if [ ! -f "$CONVERTER" ]; then
    echo "ERROR: Converter script not found: $CONVERTER"
    exit 1
fi

# Process each test directory
for test_dir in "${IMAGE_DIR}"/dpc_test_*; do
    if [ -d "$test_dir" ]; then
        dir_name=$(basename "$test_dir")
        echo ""
        echo "Processing: $dir_name"
        echo "-------------------------------------------"
        
        # Convert all PNG files in this directory
        python3 "$CONVERTER" -a "$test_dir"
        
        if [ $? -eq 0 ]; then
            echo "✓ Successfully converted images in $dir_name"
        else
            echo "✗ Failed to convert images in $dir_name"
        fi
    fi
done

echo ""
echo "==========================================="
echo "  Conversion Complete"
echo "==========================================="
