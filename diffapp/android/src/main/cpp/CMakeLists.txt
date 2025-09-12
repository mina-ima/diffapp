cmake_minimum_required(VERSION 3.10.2)
project(diffapp_ffi)

add_library(
  diffapp_ffi
  SHARED
  native-lib.cpp
)

target_include_directories(diffapp_ffi PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# Try to find OpenCV (optional). If found, link and define WITH_OPENCV.
find_package(OpenCV QUIET)
if(OpenCV_FOUND)
  message(STATUS "OpenCV found: ${OpenCV_VERSION}")
  target_include_directories(diffapp_ffi PRIVATE ${OpenCV_INCLUDE_DIRS})
  target_link_libraries(diffapp_ffi ${OpenCV_LIBS})
  target_compile_definitions(diffapp_ffi PRIVATE WITH_OPENCV=1)
else()
  message(STATUS "OpenCV not found; building without OpenCV")
endif()

find_library(log-lib log)
target_link_libraries(diffapp_ffi ${log-lib})
