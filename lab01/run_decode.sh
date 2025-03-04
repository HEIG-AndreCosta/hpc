#!/bin/bash



for file in audio/*; do
	echo "Decoding $file" 
	echo "-- Frequency Domain --"
	./build/dtmf_encdec decode $file
	echo "-- Time Domain --"
	./build/dtmf_encdec decode_time_domain $file
	echo "----------------------------------------"
done
