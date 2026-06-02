#!/usr/bin/env bash
# Switch CPU governor to 'performance' for faster builds.
# Run BEFORE 'flutter run' or 'flutter build'.
# Usage: bash perf_build.sh   (or chmod +x && ./perf_build.sh)
#
# Revert with:  bash perf_build.sh --revert

if [ "$1" = "--revert" ]; then
  echo "powersave" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
  echo "Reverted to powersave governor."
  exit 0
fi

echo "performance" | sudo tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
echo ""
cat /sys/devices/system/cpu/cpu*/cpufreq/cpuinfo_cur_freq
echo ""
echo "CPU governor set to performance. Run 'flutter run' now."
echo "After done, run:  bash perf_build.sh --revert"
