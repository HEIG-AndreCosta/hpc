#!/bin/bash



for file in audio/*; do
	echo "Decoding $file"
	./build/dtmf_encdec decode_lookup $file
	./build/dtmf_encdec decode $file
	echo "----------------------------------------"
done
