#!/bin/bash



for file in audio/*; do
	echo "Decoding $file"
	./build/dtmf_encdec decode $file
	echo "----------------------------------------"
done
