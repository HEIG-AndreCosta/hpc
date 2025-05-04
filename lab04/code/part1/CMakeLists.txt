cmake_minimum_required(VERSION 3.0)
project(HPC_lab04_smid)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON) 
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(SEG_SRC_COMMON
    src/main.c
    src/image.c
)
set(SEG_SRC_ORIGINAL
    ${SEG_SRC_COMMON}
    src/k-means-original.c
)


set(SEG_SRC_SIMD
    ${SEG_SRC_COMMON}
    src/k-means-common.c
    src/k-means-simd.c
    src/k-means-distance-simd.c
)
set(SEG_SRC
    ${SEG_SRC_COMMON}
    src/k-means-common.c
    src/k-means.c
)

set(SEG_TEST_SIMD_SRC
    src/k-means-distance-simd.c
    src/k-means-common.c
    src/test-simd.c
)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -g -Wall -fno-inline")

include_directories(
    ../lib/stb
    include/
)

add_executable(segmentation_original ${SEG_SRC_ORIGINAL})
target_link_libraries(segmentation_original m)

add_executable(segmentation ${SEG_SRC})
target_link_libraries(segmentation m)

add_executable(segmentation_simd ${SEG_SRC_SIMD})
target_link_libraries(segmentation_simd m)
target_compile_options(segmentation_simd PRIVATE -mavx)

add_executable(test_simd ${SEG_TEST_SIMD_SRC})
target_link_libraries(test_simd m)
target_compile_options(test_simd PRIVATE -mavx)
