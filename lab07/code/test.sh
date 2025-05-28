#!/bin/bash

set -e

# Build process
cmake -B build -S . 
cmake --build build -j$(nproc)

# Test
mkdir -p output

./build/k-mer-original ./inputs/pi_dec_1k.txt 3 > ./output/k-mer-original-pi-dec-1k.txt
./build/k-mer ./inputs/pi_dec_1k.txt 3 > ./output/k-mer-pi-dec-1k.txt
./build/k-mer-omp ./inputs/pi_dec_1k.txt 3 > ./output/k-mer-omp-pi-dec-1k.txt

echo "Testing original version"
cmp ./expected/expected_dec_1k.txt ./output/k-mer-original-pi-dec-1k.txt
echo "Testing single threaded optimized version"
cmp ./expected/expected_dec_1k.txt ./output/k-mer-pi-dec-1k.txt
echo "Testing omp version"
cmp ./expected/expected_dec_1k.txt ./output/k-mer-omp-pi-dec-1k.txt

echo "All tests passed"
