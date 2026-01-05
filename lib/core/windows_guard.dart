import 'dart:io';

bool gfWindowsAllowsVideo() {
  return !Platform.isWindows;
}

bool gfWindowsAllowsCamera() {
  return !Platform.isWindows;
}
