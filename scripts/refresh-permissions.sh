#!/bin/bash
# Refresh accessibility permissions for Space Cadet

echo "Killing Space Cadet..."
killall "Space Cadet" 2>/dev/null
sleep 1

echo "Opening System Settings to Accessibility permissions..."
echo "Please:"
echo "1. Find 'Space Cadet' in the list"
echo "2. UNCHECK it (turn off)"
echo "3. CHECK it again (turn back on)"
echo "4. Close System Settings"
echo ""
echo "Press Enter when done..."

open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"

read

echo "Launching Space Cadet..."
open -a "Space Cadet"

echo "Done! Test by holding Space and pressing keys."
