cmake_minimum_required(VERSION 3.10)
project(FindKmers)

set(CMAKE_C_STANDARD 99)

add_executable(k-mer-original src/main-original.c)
add_executable(k-mer src/main.c)

find_package(OpenMP REQUIRED)
add_executable(k-mer-omp src/main-omp.c)
target_link_libraries(k-mer-omp PRIVATE OpenMP::OpenMP_C)
target_compile_options(k-mer-omp PRIVATE ${OpenMP_C_FLAGS})
