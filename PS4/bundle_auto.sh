#!/bin/bash
# bundle_auto.sh - Bundle inject_auto.js with lapse_binloader.js
# Creates a single JS file that auto-runs jailbreak + binloader
# Automatically builds lapse_binloader.js from source files first

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INJECT_AUTO="$SCRIPT_DIR/inject_auto.js"
LAPSE_DIR="$SCRIPT_DIR/payloads/lapse"
PAYLOAD="$SCRIPT_DIR/payloads/lapse_binloader.js"
OUTPUT="$SCRIPT_DIR/inject_auto_bundle.js"

# Check inject_auto.js exists
if [ ! -f "$INJECT_AUTO" ]; then
    echo "ERROR: inject_auto.js not found at $INJECT_AUTO"
    exit 1
fi

# Check lapse directory exists
if [ ! -d "$LAPSE_DIR" ]; then
    echo "ERROR: lapse directory not found at $LAPSE_DIR"
    exit 1
fi

# ==========================================
# Step 1: Build lapse_binloader.js from source
# ==========================================
echo "=== Building lapse_binloader.js ==="

LAPSE_FILES=(
    "config.js"
    "kernel_offset.js"
    "misc.js"
    "kernel.js"
    "threading.js"
    "lapse_stages.js"
    "lapse_main.js"
    "binloader.js"
)

# Clear/create output file
> "$PAYLOAD"

for file in "${LAPSE_FILES[@]}"; do
    filepath="$LAPSE_DIR/$file"

    if [[ ! -f "$filepath" ]]; then
        echo "ERROR: Missing file: $filepath"
        exit 1
    fi

    echo "" >> "$PAYLOAD"
    echo "/***** $file *****/" >> "$PAYLOAD"
    echo "" >> "$PAYLOAD"
    cat "$filepath" >> "$PAYLOAD"
    echo "" >> "$PAYLOAD"

    echo "  Added: $file"
done

LAPSE_SIZE=$(wc -c < "$PAYLOAD")
echo "Built lapse_binloader.js: $LAPSE_SIZE bytes"
echo ""

# ==========================================
# Step 2: Bundle inject_auto.js + lapse_binloader.js
# ==========================================
echo "=== Building inject_auto_bundle.js ==="

# Create temp file for the bundled output
TEMP_FILE=$(mktemp)

# Read inject_auto.js up to the marker
sed -n '1,/LAPSE_BINLOADER_PAYLOAD_START/p' "$INJECT_AUTO" > "$TEMP_FILE"

# Append the payload
cat "$PAYLOAD" >> "$TEMP_FILE"

# Append the rest of inject_auto.js after the end marker
sed -n '/LAPSE_BINLOADER_PAYLOAD_END/,$p' "$INJECT_AUTO" >> "$TEMP_FILE"

# Move to output
mv "$TEMP_FILE" "$OUTPUT"

# Get file sizes
INJECT_SIZE=$(wc -c < "$INJECT_AUTO")
PAYLOAD_SIZE=$(wc -c < "$PAYLOAD")
OUTPUT_SIZE=$(wc -c < "$OUTPUT")

echo "Bundled!"
echo "  inject_auto.js:      $INJECT_SIZE bytes"
echo "  lapse_binloader.js:  $PAYLOAD_SIZE bytes"
echo "  Output:              $OUTPUT_SIZE bytes"
echo ""

# Syntax check
echo "Running syntax check..."
if node --check "$OUTPUT" 2>&1; then
    echo "Syntax OK!"
    echo ""
    echo "=== Done ==="
    echo "Output: $OUTPUT"
else
    echo ""
    echo "ERROR: Syntax check failed!"
    exit 1
fi
