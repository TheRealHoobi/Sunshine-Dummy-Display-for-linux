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
# Find these using the `sudo evtest` command and enter only the number (e.g., "5").
KEYBOARD_DEVICE_ID="5"
MOUSE_DEVICE_ID="10"

# Main monitor configuration.
# Use the format "name:resolution:position:priority".
# The position can be an absolute coordinate (e.g., "1920,0") or a relative
# keyword ("left", "right", "top", "bottom") relative to the primary display.
# The order is important! The first monitor on the list will be treated as the primary one.
MONITOR_CONFIGURATION=(
    "DP-1:2560x1440:0,0:1"
    "HDMI-A-1:1920x1080:left:2"
)

# Optional vertical offset for relative positioning.
# Use this to align monitors with a vertical shift, e.g., "180" for the position in your kscreen-doctor output.
# This value will be added to the y-coordinate of horizontally-aligned monitors.
VERTICAL_OFFSET="180"

# Virtual display configuration.
# Defines the name and resolution of the virtual monitor.
# This monitor will be active when the physical monitors are off.
VIRTUAL_DISPLAY_NAME="DP-3"
VIRTUAL_DISPLAY_RESOLUTION="2560x1440"

# Cloning setting. Set to "true" to enable cloning on the virtual monitor.
ENABLE_CLONING="false"

# Set the virtual monitor's position relative to the primary monitor.
# Available options: "left", "right", "top", "bottom".
# This option works only when ENABLE_CLONING="false".
VIRTUAL_DISPLAY_POSITION_RELATIVE_TO_PRIMARY="right"

# Logging configuration. Set to "true" to enable logging.
ENABLE_LOGGING="false"

# -------------------- END OF USER CONFIGURATION ------------------------------
# You should not need to edit anything below this line.

# Set up the full device paths
KEYBOARD_DEVICE="/dev/input/event${KEYBOARD_DEVICE_ID}"
MOUSE_DEVICE="/dev/input/event${MOUSE_DEVICE_ID}"

# Automatically parse monitor configuration
PHYSICAL_DISPLAYS=()
DISPLAY_RESOLUTIONS=()
DISPLAY_POSITIONS=()
DISPLAY_PRIORITIES=()
RELATIVE_POSITIONS_INPUT=()

for config in "${MONITOR_CONFIGURATION[@]}"; do
    IFS=':' read -r name resolution position priority <<< "$config"
    PHYSICAL_DISPLAYS+=("$name")
    DISPLAY_RESOLUTIONS+=("$resolution")
    DISPLAY_PRIORITIES+=("$priority")

    # Check if the position is a coordinate or a relative keyword
    if [[ "$position" =~ , ]]; then
        DISPLAY_POSITIONS+=("$position")
        RELATIVE_POSITIONS_INPUT+=("absolute")
    else
        DISPLAY_POSITIONS+=("0,0") # Placeholder
        RELATIVE_POSITIONS_INPUT+=("$position")
    fi
done

# Set the primary monitor
PRIMARY_DISPLAY_NAME="${PHYSICAL_DISPLAYS[0]}"
PRIMARY_DISPLAY_RESOLUTION="${DISPLAY_RESOLUTIONS[0]}"
PRIMARY_DISPLAY_POSITION="${DISPLAY_POSITIONS[0]}"

# Calculate the lowest priority for the virtual monitor.
VIRTUAL_PRIORITY=$((${#PHYSICAL_DISPLAYS[@]} + 1))

# Configure log redirection
if [[ "$ENABLE_LOGGING" == "true" ]]; then
    LOG_FILE="$HOME/sunshine_monitor_log.txt"
    LOG_REDIRECT=">> \"$LOG_FILE\" 2>&1"
else
    LOG_FILE="/dev/null"
    LOG_REDIRECT=">> /dev/null 2>&1"
fi

# Start logging
echo "==========================================================" >> "$LOG_FILE"
echo "Script started at $(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG_FILE"

# 1. Disable physical monitors and enable the virtual one.
echo "Disabling physical monitors and enabling the virtual one. The script is now listening for input events..." >> "$LOG_FILE"
for display in "${PHYSICAL_DISPLAYS[@]}"; do
    kscreen-doctor "output.${display}.disable" $LOG_REDIRECT
done

kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.enable" $LOG_REDIRECT
kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.mode.${VIRTUAL_DISPLAY_RESOLUTION}" $LOG_REDIRECT
kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.priority.${VIRTUAL_PRIORITY}" $LOG_REDIRECT

# Set cloning or position based on configuration
if [[ "$ENABLE_CLONING" == "true" ]]; then
    kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.clone.${PRIMARY_DISPLAY_NAME}" $LOG_REDIRECT
else
    # Calculate virtual monitor position relative to the primary one
    IFS='x' read -r primary_width primary_height <<< "$PRIMARY_DISPLAY_RESOLUTION"
    IFS=',' read -r primary_x primary_y <<< "$PRIMARY_DISPLAY_POSITION"

    case "$VIRTUAL_DISPLAY_POSITION_RELATIVE_TO_PRIMARY" in
        "left")
            virtual_x=$((primary_x - primary_width))
            virtual_y=$primary_y
            ;;
        "right")
            virtual_x=$((primary_x + primary_width))
            virtual_y=$primary_y
            ;;
        "top")
            virtual_x=$primary_x
            virtual_y=$((primary_y - primary_height))
            ;;
        "bottom")
            virtual_x=$primary_x
            virtual_y=$((primary_y + primary_height))
            ;;
        *)
            # Default position if the option is unknown
            virtual_x=$((primary_x + primary_width))
            virtual_y=$primary_y
            ;;
    esac

    kscreen-doctor "output.${VIRTUAL_DISPLAY_NAME}.position.${virtual_x},${virtual_y}" $LOG_REDIRECT
fi

# 2. Listen for mouse or key press (concurrently)
# Run both evtest commands in the background and save their process IDs.
echo "$(date '+%Y-%m-%d %H:%M:%S'): Listening for keyboard and mouse events." >> "$LOG_FILE"
sudo -S evtest "$KEYBOARD_DEVICE" | grep -m 1 "Event: time" &
KEYBOARD_PID=$!
sudo -S evtest "$MOUSE_DEVICE" | grep -m 1 "Event: time" &
MOUSE_PID=$!

# Wait for either process to complete
wait -n

# 3. Stop the other process to prevent it from running indefinitely.
echo "$(date '+%Y-%m-%d %H:%M:%S'): Input detected. Stopping listening processes." >> "$LOG_FILE"
kill $KEYBOARD_PID &>/dev/null
kill $MOUSE_PID &>/dev/null

# 4. Enable physical monitors and set their positions.
echo "Input detected! Physical monitors are being re-enabled." >> "$LOG_FILE"
declare -A relative_offsets
relative_offsets[left]=0
relative_offsets[right]=0
relative_offsets[top]=0
relative_offsets[bottom]=0

for i in "${!PHYSICAL_DISPLAYS[@]}"; do
    display="${PHYSICAL_DISPLAYS[$i]}"
    position_type="${RELATIVE_POSITIONS_INPUT[$i]}"
    resolution="${DISPLAY_RESOLUTIONS[$i]}"
    position="${DISPLAY_POSITIONS[$i]}"

    kscreen-doctor "output.${display}.enable" $LOG_REDIRECT

    if [[ "$position_type" == "absolute" ]]; then
        kscreen-doctor "output.${display}.position.${position}" $LOG_REDIRECT
    else
        IFS='x' read -r current_width current_height <<< "$resolution"
        IFS=',' read -r primary_x primary_y <<< "$PRIMARY_DISPLAY_POSITION"

        case "$position_type" in
            "left")
                new_x=$((primary_x - current_width - relative_offsets[left]))
                new_y=$((primary_y + VERTICAL_OFFSET))
                relative_offsets[left]=$((relative_offsets[left] + current_width))
                ;;
            "right")
                new_x=$((primary_x + primary_width + relative_offsets[right]))
                new_y=$((primary_y + VERTICAL_OFFSET))
                relative_offsets[right]=$((relative_offsets[right] + current_width))
                ;;
            "top")
                new_x=$primary_x
                new_y=$((primary_y - current_height - relative_offsets[top]))
                relative_offsets[top]=$((relative_offsets[top] + current_height))
                ;;
            "bottom")
                new_x=$primary_x
                new_y=$((primary_y + primary_height + relative_offsets[bottom]))
                relative_offsets[bottom]=$((relative_offsets[bottom] + current_height))
                ;;
            *)
                # Fallback to absolute position if type is unknown
                new_x=$((primary_x + primary_width))
                new_y=$primary_y
                ;;
        esac

        kscreen-doctor "output.${display}.position.${new_x},${new_y}" $LOG_REDIRECT
    fi
done

# 5. Set display priorities (optional)
if [[ ${#DISPLAY_PRIORITIES[@]} -gt 0 ]]; then
    for i in "${!PHYSICAL_DISPLAYS[@]}"; do
        display="${PHYSICAL_DISPLAYS[$i]}"
        priority="${DISPLAY_PRIORITIES[$i]}"
        kscreen-doctor "output.${display}.priority.${priority}" $LOG_REDIRECT
    done
fi

echo "Physical monitors have been re-enabled. The script has finished." >> "$LOG_FILE"
echo "==========================================================" >> "$LOG_FILE"
