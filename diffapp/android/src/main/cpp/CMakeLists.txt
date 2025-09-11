cmake_minimum_required(VERSION 3.10.2)
project(diffapp_ffi)

add_library(
  diffapp_ffi
  SHARED
  native-lib.cpp
)

target_include_directories(diffapp_ffi PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

find_library(log-lib log)
target_link_libraries(diffapp_ffi ${log-lib})

