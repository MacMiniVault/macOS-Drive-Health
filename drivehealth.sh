#!/bin/bash

echo -e "\n---------------\n"

# Download smartmontools to /tmp
curl -L -o /tmp/smartmontools.dmg https://sourceforge.net/projects/smartmontools/files/smartmontools/7.3/smartmontools-7.3-1.dmg/download >/dev/null 2>&1

# Mount the dmg
hdiutil attach /tmp/smartmontools.dmg >/dev/null

# Extract the pkg files
pkgutil --expand /Volumes/smartmontools/smartmontools-7.3-1.pkg /tmp/smartmontools >/dev/null

# Extract the Payload (gzip)
tar -xf /tmp/smartmontools/Payload -C /tmp/smartmontools/ >/dev/null

smartctl_path="/tmp/smartmontools/usr/local/sbin/smartctl"

# Get a list of all internal drives
DRIVES=($(diskutil list | grep "internal" | awk '{print $1}'))

# Tell user how many drives were detected
echo "Detected ${#DRIVES[@]} internal drive(s)"

# Perform checks on drive(s)
for DRIVE in "${DRIVES[@]}"; do
  echo -e "\n---------------\n"
  # Get drive info
  INFO=$($smartctl_path -i "$DRIVE")

  # Determine if the drive is SSD or HDD
  if echo "$INFO" | grep -q "SSD"; then
    TYPE="SSD"
  else
    TYPE="HDD"
  fi

  # Check for errors and report results
  if [ "$TYPE" = "SSD" ]; then
    echo "SSD detected on $DRIVE"
    $smartctl_path -H "$DRIVE"
  else
    echo "HDD detected on $DRIVE"
    HOURS=$($smartctl_path -a "$DRIVE" | grep Power_On_Hours | awk '{print $10}')
    if [ -n "$HOURS" ] && [ "$HOURS" -gt 30000 ]; then
      echo "Drive $DRIVE is too old, over 30000 hours"
    fi
    $smartctl_path -H "$DRIVE"
  fi
  
  # Tell user if drive is healthy or failing
  HEALTH=$($smartctl_path -H "$DRIVE")
  if [[ $HEALTH == *"PASSED"* ]]; then
    echo "$DRIVE is healthy"
  else
    echo "WARNING: $DRIVE is FAILING"
  fi
  echo -e "\n---------------\n"
done

# Detach the dmg
hdiutil detach /Volumes/smartmontools >/dev/null

# Remove smartctl and other downloaded files from /tmp when done
rm -rf /tmp/smartmontools /tmp/smartmontools.dmg
