cmake_minimum_required(VERSION 3.22.1)
project(native-lib)

add_library(native-lib SHARED native-lib.cpp)

find_library(log-lib log)
target_link_libraries(native-lib ${log-lib})

# OpenCV (Android NDK) linkage: optional for CI builds
option(OPENCV_OPTIONAL "Allow building without OpenCV present" ON)
if(OPENCV_OPTIONAL)
  # COMPONENTS を明示して core/imgproc/features2d を要求
  find_package(OpenCV QUIET COMPONENTS core imgproc features2d)
  if(OpenCV_FOUND)
    include_directories(${OpenCV_INCLUDE_DIRS})
    target_link_libraries(native-lib ${OpenCV_LIBS})
  else()
    message(STATUS "OpenCV not found; skipping linkage for CI build")
  endif()
else()
  # COMPONENTS を明示（必須）
  find_package(OpenCV REQUIRED COMPONENTS core imgproc features2d)
  include_directories(${OpenCV_INCLUDE_DIRS})
  target_link_libraries(native-lib ${OpenCV_LIBS})
endif()

# --- Native test executables (optional; off by default) ---
# Enable with: -DBUILD_NATIVE_TESTS=ON
option(BUILD_NATIVE_TESTS "Build native gtest targets" OFF)
if(BUILD_NATIVE_TESTS)
  # These targets allow local NDK builds for algorithm tests.
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
endif()
