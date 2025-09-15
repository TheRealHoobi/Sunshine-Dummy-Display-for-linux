#!/bin/bash

# ==============================================================================
#                      SUNSHINE HEADLESS MONITOR CONTROL
# ==============================================================================
# This script is designed to automatically manage physical displays for
# a Sunshine streaming setup. It disables monitors for power saving and
# re-enables them upon detecting keyboard or mouse input.
# ==============================================================================


# -------------------------- USER CONFIGURATION -------------------------------
# Please modify these variables to match your system's setup.

# Evtest event IDs for your mouse and keyboard.
# Find these using the `sudo evtest` command and enter only the number.
KEYBOARD_DEVICE_ID="5"
MOUSE_DEVICE_ID="10"

# List the names of your physical display outputs.
# Find these names using `kscreen-doctor -o` or `xrandr --query`.
# The order here must match the order in the arrays below.
PHYSICAL_DISPLAYS=(
    "HDMI-A-1"
    "DP-1"
)

# Define the positions for your physical displays when they are enabled.
# The format is `x_position,y_position`.
# The order must match the PHYSICAL_DISPLAYS array.
DISPLAY_POSITIONS=(
    "0,180"
    "1920,0"
)

# Define the priorities for your physical displays.
# Priority 1 is the primary display. You can leave this empty if you don't use it.
# The order must match the PHYSICAL_DISPLAYS array.
DISPLAY_PRIORITIES=(
    "1"
    "2"
)

# Virtual display configuration
# Define the name and resolution for your virtual display.
VIRTUAL_DISPLAY_NAME="DP-3"
VIRTUAL_DISPLAY_RESOLUTION="2560x1440"

# Set the primary physical display that the virtual display will clone.
PRIMARY_DISPLAY_NAME="DP-1"

# -------------------- END OF USER CONFIGURATION ------------------------------
# You should not need to edit anything below this line.

# Set up the full device paths
KEYBOARD_DEVICE="/dev/input/event${KEYBOARD_DEVICE_ID}"
MOUSE_DEVICE="/dev/input/event${MOUSE_DEVICE_ID}"

# Calculate the lowest priority for the virtual display.
VIRTUAL_PRIORITY=$((${#PHYSICAL_DISPLAYS[@]} + 1))

# 1. Disable all physical monitors and enable the virtual display.
echo "Disabling physical monitors and enabling the virtual one. The script is now listening for input events..."
for display in "${PHYSICAL_DISPLAYS[@]}"; do
    kscreen-doctor "output.${display}.disable" 
done

kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.enable"
kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.mode.${VIRTUAL_DISPLAY_RESOLUTION}"
kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.clone.${PRIMARY_DISPLAY_NAME}"
kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.priority.${VIRTUAL_PRIORITY}"

# 2. Listen for mouse or key press (concurrently)
# Run both evtest commands in the background and save their process IDs.
echo "$(date '+%Y-%m-%d %H:%M:%S'): Listening for keyboard and mouse events."
sudo -S evtest "$KEYBOARD_DEVICE" | grep -m 1 "Event: time" &
KEYBOARD_PID=$!
sudo -S evtest "$MOUSE_DEVICE" | grep -m 1 "Event: time" &
MOUSE_PID=$!

# Wait for either process to complete
wait -n

# 3. Stop the other process to prevent it from running indefinitely.
echo "$(date '+%Y-%m-%d %H:%M:%S'): Input detected. Stopping listening processes."
kill $KEYBOARD_PID &>/dev/null
kill $MOUSE_PID &>/dev/null

# 4. Enable physical monitors and disable the virtual one.
echo "Input detected! Physical monitors are being re-enabled."

kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.disable"

for i in "${!PHYSICAL_DISPLAYS[@]}"; do
    display="${PHYSICAL_DISPLAYS[$i]}"
    position="${DISPLAY_POSITIONS[$i]}"
    kscreen-doctor "output.${display}.enable"
    kscreen-doctor "output.${display}.position.${position}"
done

# 5. Set display priorities (optional)
if [[ ${#DISPLAY_PRIORITIES[@]} -gt 0 ]]; then
    for i in "${!PHYSICAL_DISPLAYS[@]}"; do
        display="${PHYSICAL_DISPLAYS[$i]}"
        priority="${DISPLAY_PRIORITIES[$i]}"
        kscreen-doctor "output.${display}.priority.${priority}"
    done
fi

echo "Physical monitors have been re-enabled. The script has finished."
echo "=========================================================="
