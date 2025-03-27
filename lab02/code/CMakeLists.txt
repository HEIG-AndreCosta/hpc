cmake_minimum_required(VERSION 3.10)
project(lab02 C)

find_path(SNDFILE_INCLUDE_DIR sndfile.h REQUIRED)
find_library(SNDFILE_LIBRARY sndfile REQUIRED)

if(NOT SNDFILE_INCLUDE_DIR OR NOT SNDFILE_LIBRARY)
    message(FATAL_ERROR "libsndfile non trouvé. Assurez-vous que libsndfile1 et libsndfile1-dev sont installés.")
endif()

# Définir les options de compilation
set(CMAKE_C_STANDARD 11)
set(CMAKE_C_FLAGS "-O0 -g -Wall -fno-inline -DLIKWID_PERFMON")
set(DEBUG_FLAGS "-std=c11 -Wall -Wextra -pedantic -g")

# Inclure les répertoires d'en-têtes
include_directories(../../lib/stb/ ../include)

# Chercher tous les fichiers sources
file(GLOB SOURCES_test "src/test_likwid.c")

# Créer l'exécutable
add_executable(test_likwid ${SOURCES_test})

set(SRC src/main.c
        src/buffer.c 
        src/dtmf.c 
        src/file.c 
        src/wave.c 
        src/utils.c 
        src/fft.c 
        src/dtmf_encoder.c 
        src/dtmf_decoder.c
)

add_executable(dtmf_encdec ${SRC})

# Lier les bibliothèques
target_link_libraries(test_likwid m likwid)
target_link_libraries(dtmf_encdec ${SNDFILE_LIBRARY} m likwid)

# Cible pour le mode debug
add_custom_target(debug
    COMMAND ${CMAKE_COMMAND} -DCMAKE_BUILD_TYPE=Debug ${CMAKE_SOURCE_DIR} && ${CMAKE_BUILD_TOOL}
    WORKING_DIRECTORY ${CMAKE_BINARY_DIR}
)

# Spécifier les cibles comme PHONY
target_sources(test_likwid PRIVATE ${SOURCES_test})
target_sources(dtmf_encdec PRIVATE ${SRC})
