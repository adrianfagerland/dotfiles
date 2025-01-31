#!/bin/bash

# Define your display outputs
INTERNAL_DISPLAY="eDP-1"  # Replace with your internal display identifier
EXTERNAL_DISPLAY="HDMI-1" # Replace with your external display identifier

# Generate the menu
MENU="$(echo -e "💻 Internal Only\n🖥️ External Only\n🖥️💻 Mirror Displays\n💻➡️🖥️ Extend Right\n🖥️⬅️💻 Extend Left" | rofi -dmenu -p "Display Configuration")"

# Apply the selected configuration
case "$MENU" in
  "💻 Internal Only")
    xrandr --output $INTERNAL_DISPLAY --auto --primary --output $EXTERNAL_DISPLAY --off
    ;;
  "🖥️ External Only")
    xrandr --output $INTERNAL_DISPLAY --off --output $EXTERNAL_DISPLAY --auto --primary
    ;;
  "🖥️💻 Mirror Displays")
    xrandr --output $INTERNAL_DISPLAY --auto --output $EXTERNAL_DISPLAY --auto --same-as $INTERNAL_DISPLAY
    ;;
  "💻➡️🖥️ Extend Right")
    xrandr --output $INTERNAL_DISPLAY --auto --primary --output $EXTERNAL_DISPLAY --auto --right-of $INTERNAL_DISPLAY
    ;;
  "🖥️⬅️💻 Extend Left")
    xrandr --output $INTERNAL_DISPLAY --auto --primary --output $EXTERNAL_DISPLAY --auto --left-of $INTERNAL_DISPLAY
    ;;
  *)
    echo "No valid option selected."
    exit 1
    ;;
esac

# Pause for 3 seconds to allow display settings to apply
sleep 1

# Reload i3 configuration
i3-msg restart
