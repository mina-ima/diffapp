cmake_minimum_required(VERSION 3.22.1)
project(native-lib)

add_library(native-lib SHARED native-lib.cpp)

find_library(log-lib log)
target_link_libraries(native-lib ${log-lib})

# OpenCV (Android NDK) linkage: optional for CI builds
option(OPENCV_OPTIONAL "Allow building without OpenCV present" ON)
if(OPENCV_OPTIONAL)
  find_package(OpenCV QUIET core imgproc features2d)
  if(OpenCV_FOUND)
    include_directories(${OpenCV_INCLUDE_DIRS})
    target_link_libraries(native-lib ${OpenCV_LIBS})
  else()
    message(STATUS "OpenCV not found; skipping linkage for CI build")
  endif()
else()
  find_package(OpenCV REQUIRED core imgproc features2d)
  include_directories(${OpenCV_INCLUDE_DIRS})
  target_link_libraries(native-lib ${OpenCV_LIBS})
endif()

# --- Native test executables (not wired to CI yet) ---
# These targets allow local NDK builds for algorithm tests. Linking to external
# libs (e.g., OpenCV) is omitted for now.

# GoogleTest (FetchContent)
include(FetchContent)
FetchContent_Declare(
  googletest
  URL https://github.com/google/googletest/archive/refs/tags/v1.14.0.zip
)
FetchContent_MakeAvailable(googletest)

add_executable(orb_sift_matching_test
  tests/orb_sift_matching_test.cpp
)
if(OpenCV_FOUND)
  target_link_libraries(orb_sift_matching_test gtest_main ${OpenCV_LIBS})
else()
  target_link_libraries(orb_sift_matching_test gtest_main)
endif()

add_executable(ssim_numeric_test
  tests/ssim_numeric_test.cpp
)
if(OpenCV_FOUND)
  target_link_libraries(ssim_numeric_test gtest_main ${OpenCV_LIBS})
else()
  target_link_libraries(ssim_numeric_test gtest_main)
endif()

add_executable(nms_dedup_test
  tests/nms_dedup_test.cpp
)
if(OpenCV_FOUND)
  target_link_libraries(nms_dedup_test gtest_main ${OpenCV_LIBS})
else()
  target_link_libraries(nms_dedup_test gtest_main)
endif()
