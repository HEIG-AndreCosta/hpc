cmake_minimum_required(VERSION 3.0)
project(HPC_lab04_smid)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_STANDARD_REQUIRED ON)

set(GRAYSCALE_SRC_COMMON src/main.c src/image.c)
set(GRAYSCALE_SRC ${GRAYSCALE_SRC_COMMON} src/grayscale.c)

set(GRAYSCALE_SRC_SIMD ${GRAYSCALE_SRC_COMMON} src/grayscale-simd.c)

set(GRAYSCALE_TEST src/test.c src/grayscale.c src/grayscale-simd.c)

set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -O3 -g -Wall")

include_directories(../lib/stb include/)

add_executable(grayscale ${GRAYSCALE_SRC})
target_link_libraries(grayscale m)

add_executable(grayscale_simd ${GRAYSCALE_SRC_SIMD})
target_link_libraries(grayscale_simd m)
target_compile_options(grayscale_simd PRIVATE -mavx2)
target_compile_definitions(grayscale_simd PRIVATE SIMD)

add_executable(test ${GRAYSCALE_TEST})
target_link_libraries(test m)
target_compile_options(test PRIVATE -mavx2)
