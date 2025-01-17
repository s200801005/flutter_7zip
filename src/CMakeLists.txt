# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(flutter_7zip_library VERSION 0.0.1 LANGUAGES C)

add_library(flutter_7zip SHARED
  "flutter_7zip.c"
)

set_target_properties(flutter_7zip PROPERTIES
  PUBLIC_HEADER flutter_7zip.h
  OUTPUT_NAME "flutter_7zip"
)

target_compile_definitions(flutter_7zip PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(flutter_7zip PRIVATE "-Wl,-z,max-page-size=16384")
endif()
