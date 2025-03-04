#include "dtmf_private.h"

#include "buffer.h"
#include "utils.h"
#include "fft.h"
#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#define MIN_FREQ	    697
#define MAX_FREQ	    1500
#define SPECIAL_BUTTON_CHAR '*'

static float get_amplitude(const float *buffer, size_t len);
static uint8_t closest_row(uint32_t freq);
static uint8_t closest_col(uint32_t freq);
static uint8_t closest(const uint16_t *values, size_t len, uint32_t freq);
static bool is_valid_frequency(uint32_t freq);

static inline size_t decode_samples_to_skip_on_silence(uint32_t sample_rate)
{
	return CHAR_PAUSE_SAMPLES(sample_rate) -
	       SAME_CHAR_PAUSE_SAMPLES(sample_rate);
}
static inline size_t decode_samples_to_skip_on_press(uint32_t sample_rate)
{
	return CHAR_SOUND_SAMPLES(sample_rate) +
	       SAME_CHAR_PAUSE_SAMPLES(sample_rate);
}

const char *dtmf_err_to_string(dtmf_err_t err)
{
	switch (err) {
	case DTMF_OK:
		return "dtmf ok";
	case DTMF_INVALID_ENCODING_STRING:
		return "dtmf invalid encoding string";
	case DTMF_NO_MEMORY:
		return "dtmf no memory";
	}
	return "dtmf unknown error";
}

char *dtmf_decode(dtmf_t *dtmf)
{
	size_t len = SAME_CHAR_PAUSE_SAMPLES(dtmf->sample_rate);
	if (!is_power_of_2(len)) {
		len = align_to_power_of_2(len);
	}

	cplx_t *buffer = calloc(len, sizeof(*buffer));
	if (!buffer) {
		printf("Failed to allocate memory for decode\n");
		return NULL;
	}
	buffer_t result;
	int ret = buffer_init(&result, 128, sizeof(char));
	if (ret < 0) {
		printf("Failed to allocate memory for decode result\n");
		free(buffer);
		return NULL;
	}

	const size_t samples_to_skip_on_silence =
		decode_samples_to_skip_on_silence(dtmf->sample_rate);
	const size_t samples_to_skip_on_press =
		decode_samples_to_skip_on_press(dtmf->sample_rate);
	uint32_t f1 = 0, f2 = 0;
	float btn_amplitude = 0;
	size_t i = 0;

	/* First find the start of the file */
	while ((i + len) < dtmf->buffer.len) {
		float_to_cplx_t((float *)dtmf->buffer.data + i, buffer, len);

		int err = fft(buffer, len);
		if (err != 0) {
			printf("Error running fft\n");
			return NULL;
		}
		extract_frequencies(buffer, len, dtmf->sample_rate, &f1, &f2);

		if (is_valid_frequency(f1) && is_valid_frequency(f2)) {
			/* Found the start of the file */
			const float amplitude = get_amplitude(
				(float *)dtmf->buffer.data + i, len);

			btn_amplitude = amplitude - (amplitude / 10);
			printf("Using %g as silence amplitude threshold\n",
			       btn_amplitude);
			break;
		} else {
			i += len;
		}
	}

	size_t btn = 0xFF;
	size_t consecutive_presses = 0;
	while ((i + len) < dtmf->buffer.len) {
		const float amplitude =
			get_amplitude((float *)dtmf->buffer.data + i, len);

		if (amplitude < btn_amplitude) {
			const char decoded =
				dtmf_decode_character(btn, consecutive_presses);
			buffer_push(&result, &decoded);
			consecutive_presses = 0;
			i += samples_to_skip_on_silence;
			continue;
		}

		float_to_cplx_t((float *)dtmf->buffer.data + i, buffer, len);

		int err = fft(buffer, len);
		if (err != 0) {
			printf("Error running fft\n");
			return NULL;
		}
		extract_frequencies(buffer, len, dtmf->sample_rate, &f1, &f2);

		if (!(is_valid_frequency(f1) && is_valid_frequency(f2))) {
			const char decoded =
				dtmf_decode_character(btn, consecutive_presses);
			buffer_push(&result, &decoded);
			consecutive_presses = 0;
			i += samples_to_skip_on_silence;
			continue;
		}

		uint8_t row, col;
		if (f1 < 1000) {
			row = closest_row(f1);
			col = closest_col(f2);
		} else {
			row = closest_row(f2);
			col = closest_col(f1);
		}
		consecutive_presses++;
		btn = row * 3 + col;
		i += samples_to_skip_on_press;
	}

	/* If the file ended without a silence, add the last button */
	if (consecutive_presses != 0) {
		const char decoded =
			dtmf_decode_character(btn, consecutive_presses);
		buffer_push(&result, &decoded);
	}
	const char terminator = '\0';
	buffer_push(&result, &terminator);
	free(buffer);
	return (char *)result.data;
}

void dtmf_terminate(dtmf_t *dtmf)
{
	buffer_terminate(&dtmf->buffer);
}

static float get_amplitude(const float *buffer, size_t len)
{
	float amplitude = 0;

	for (size_t i = 0; i < len; ++i) {
		if (buffer[i] > amplitude) {
			amplitude = buffer[i];
		}
	}
	return amplitude;
}

static uint8_t closest(const uint16_t *values, size_t len, uint32_t freq)
{
	int diff = 0xFFFF;
	uint8_t closest = 0;
	for (size_t i = 0; i < len; ++i) {
		const int curr_diff = abs(values[i] - (int)freq);
		if (curr_diff < diff) {
			closest = i;
			diff = curr_diff;
		}
	}
	return closest;
}
static uint8_t closest_row(uint32_t freq)
{
	return closest(ROW_FREQ, sizeof(ROW_FREQ) / sizeof(ROW_FREQ[0]), freq);
}
static uint8_t closest_col(uint32_t freq)
{
	return closest(COL_FREQ, sizeof(COL_FREQ) / sizeof(COL_FREQ[0]), freq);
}
static bool is_valid_frequency(uint32_t freq)
{
	return freq > 650 && freq < 1500;
}
