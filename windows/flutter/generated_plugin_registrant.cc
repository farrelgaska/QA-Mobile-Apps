//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <file_selector_windows/file_selector_windows.h>
#include <geolocator_windows/geolocator_windows.h>
<<<<<<< HEAD
#include <sentry_flutter/sentry_flutter_plugin.h>
=======
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394

void RegisterPlugins(flutter::PluginRegistry* registry) {
  FileSelectorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("FileSelectorWindows"));
  GeolocatorWindowsRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("GeolocatorWindows"));
<<<<<<< HEAD
  SentryFlutterPluginRegisterWithRegistrar(
      registry->GetRegistrarForPlugin("SentryFlutterPlugin"));
=======
>>>>>>> 8602557114f17fb0a9c151afc5909dc6e4baf394
}
