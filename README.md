# 🌞 Dummy Screen setup for Linux for Sunshine purposes

This guide will help you configure a dummy monitor for Sunshine on Manjaro (and i hope other distro too!). This is perfect for daily drivers where you dont want to have physical displays on all the time. 🎮

# TL/DR

This script automatically disable your physical displays, allowing power saving but keeping dummy display on. Evtool reads user input from keyboard/mouse movement and bring physical displays back on to they oryginal posiotion.

# Tested on

- Manjaro
- KDE Plasma (Wayland)

# 🛠️ Step 1: Install Dependencies
First, let's install the `evtest` utility, which is essential for identifying your input devices and monitor idle state.

For Manjaro/Arch-based systems:
```
sudo pacman -S evtest
```

For Debian/Ubuntu-based systems:
```
sudo apt-get install evtest
```
For Fedora/RHEL-based systems:
```
sudo dnf install evtest
```
# 🖥️ Step 2: Export Your Monitor's EDID
The EDID (Extended Display Identification Data) contains vital information about a monitor's capabilities. We'll export this from an existing monitor to use it for our dummy display.

Find your physical display EDID in `/sys/class/drm/*/edid`

or

Use script

```
for edid_file in /sys/class/drm/*/edid; do
  status_file="${edid_file%/edid}/status"
  if [ -f "$status_file" ] && grep -qx "connected" "$status_file"; then
    echo "connected: $edid_file"
  fi
done
```

Now, create the necessary directory and export the EDID to a file named `dummy.bin`. Remember to replace `card-0-DP-1` with your chosen monitor's output name.

```
sudo mkdir -p /lib/firmware/edid
sudo cat /sys/class/drm/card0-HDMI-A-1/edid > /lib/firmware/edid/dummy.bin   
```

# ⚙️ Step 3: Modify GRUB Configuration

The next step is to tell your system to use the exported EDID file and set a virtual resolution for the new display.

Open the GRUB configuration file using a text editor:

```
sudo nano /etc/default/grub
```
Find the line GRUB_CMDLINE_LINUX and add the following parameters inside the quotes. Make sure to replace `DP-3` with your unused video output port and, if needed, change the resolution (e.g. 1920x1080@60e).

```
GRUB_CMDLINE_LINUX="drm.edid_firmware=DP-3:edid/dummy.bin video=DP-3:1920x1080@60e"
```
Save the file and exit the editor. Then, update GRUB for the changes to take effect on the next boot. 🚀

```
sudo update-grub
```

# 🔐 Step 4: Configure Passwordless evtest Access

To make the work, we'll allow your user to run evtest with `sudo` in script without password.

Create a new file in the sudoers.d directory.

```
sudo nano /etc/sudoers.d/evtest
```
Add this line to the file, replacing `user` with your actual username:

```
user ALL=(ALL:ALL) NOPASSWD:/usr/bin/evtest
```

Save the file and close the editor.

# ⌨️ Step 5: Identify Your Mouse and Keyboard Events
Finally, use evtest to find the specific event numbers for your mouse and keyboard. Sunshine needs these to correctly capture your input.

Run evtest to list all available devices:

```
sudo evtest
```

You will see a list of devices with their corresponding event numbers, for example:

```
/dev/input/event8:      SINO WEALTH Gaming KB  Keyboard
/dev/input/event9:      SINO WEALTH Gaming KB  Mouse
/dev/input/event10:     SteelSeries SteelSeries Prime Wireless
```

Write down the event numbers for your devices. You will need to use these in script configuration.

With this setup, you can now enjoy Sunshine with physical displays turned off! ✨
