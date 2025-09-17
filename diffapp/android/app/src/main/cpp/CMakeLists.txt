cmake_minimum_required(VERSION 3.22.1)
project(native-lib)

add_library(native-lib SHARED native-lib.cpp)

find_library(log-lib log)
target_link_libraries(native-lib ${log-lib})

# --- Native test executables (not wired to CI yet) ---
# These targets allow local NDK builds for algorithm tests. Linking to external
# libs (e.g., OpenCV) is omitted for now.

add_executable(orb_sift_matching_test
  tests/orb_sift_matching_test.cpp
)

add_executable(ssim_numeric_test
  tests/ssim_numeric_test.cpp
)

add_executable(nms_dedup_test
  tests/nms_dedup_test.cpp
)
