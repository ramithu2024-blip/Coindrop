#!/bin/bash
cd /home/ramithu/Apps/coindrop
flutter clean 2>&1
flutter pub get 2>&1
flutter build apk --debug 2>&1
echo "BUILD_EXIT_CODE=$?"
