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
static bool is_silence(const float *buffer, size_t len, float target);
static bool is_valid_frequency(uint32_t freq);
static int push_decoded(dtmf_button_t *btn, buffer_t *result, size_t *presses);
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

	dtmf_button_t *btn = NULL;
	size_t consecutive_presses = 0;
	while ((i + len) < dtmf->buffer.len) {
		if (is_silence((float *)dtmf->buffer.data + i, len,
			       btn_amplitude)) {
			push_decoded(btn, &result, &consecutive_presses);
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
			push_decoded(btn, &result, &consecutive_presses);
			i += samples_to_skip_on_silence;
			continue;
		}
		btn = dtmf_get_closest_button(f1, f2);
		consecutive_presses++;
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
static int push_decoded(dtmf_button_t *btn, buffer_t *result, size_t *presses)
{
	const char decoded = dtmf_decode_character(btn, *presses);
	*presses = 0;
	return buffer_push(result, &decoded);
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

static bool is_silence(const float *buffer, size_t len, float target)
{
	for (size_t i = 0; i < len; ++i) {
		if (buffer[i] >= target) {
			return false;
		}
	}
	return true;
}

static bool is_valid_frequency(uint32_t freq)
{
	return freq > 650 && freq < 1500;
}
