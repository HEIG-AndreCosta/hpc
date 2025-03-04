#include "dtmf.h"
#include "dtmf_private.h"

#include "buffer.h"
#include "utils.h"
#include "fft.h"
#include <assert.h>
#include <math.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#define MIN_FREQ	    697
#define MAX_FREQ	    1500
#define SPECIAL_BUTTON_CHAR '*'

typedef dtmf_button_t *(*dtmf_decode_button_cb_t)(const float *signal,
						  cplx_t *buffer, size_t len,
						  uint32_t sample_rate);

static dtmf_button_t *decode_button_frequency_domain(const float *signal,
						     cplx_t *buffer, size_t len,
						     uint32_t sample_rate);

static dtmf_button_t *decode_button_time_domain(const float *signal,
						cplx_t *buffer, size_t len,
						uint32_t sample_rate);

static const uint16_t ROW_FREQUENCIES[] = { 697, 770, 852, 941 };
static const uint16_t COL_FREQUENCIES[] = { 1209, 1336, 1477 };

static float calculate_correlation(const float *signal, size_t len,
				   uint16_t row_freq, uint16_t col_freq,
				   uint32_t sample_rate);
static float get_amplitude(const float *buffer, size_t len);
static bool is_silence(const float *buffer, size_t len, float target);
static bool is_valid_frequency(uint32_t freq);
static int push_decoded(dtmf_button_t *btn, buffer_t *result, size_t *presses);
static ssize_t find_start_of_file(dtmf_t *dtmf, cplx_t *buffer, size_t len,
				  float *amplitude);

static char *dtmf_decode_internal(dtmf_t *dtmf,
				  dtmf_decode_button_cb_t decode_button_fn);

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

char *dtmf_decode_time_domain(dtmf_t *dtmf)
{
	return dtmf_decode_internal(dtmf, decode_button_time_domain);
}

char *dtmf_decode(dtmf_t *dtmf)
{
	return dtmf_decode_internal(dtmf, decode_button_frequency_domain);
}

static char *dtmf_decode_internal(dtmf_t *dtmf,
				  dtmf_decode_button_cb_t decode_button_fn)
{
	const size_t samples_to_skip_on_silence =
		decode_samples_to_skip_on_silence(dtmf->sample_rate);
	const size_t samples_to_skip_on_press =
		decode_samples_to_skip_on_press(dtmf->sample_rate);
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
	float target_amplitude = 0;

	size_t i = find_start_of_file(dtmf, buffer, len, &target_amplitude);

	dtmf_button_t *btn = NULL;
	size_t consecutive_presses = 0;
	while ((i + len) < dtmf->buffer.len) {
		if (is_silence((float *)dtmf->buffer.data + i, len,
			       target_amplitude)) {
			push_decoded(btn, &result, &consecutive_presses);
			i += samples_to_skip_on_silence;
			continue;
		}

		dtmf_button_t *new_btn =
			decode_button_fn((float *)dtmf->buffer.data + i, buffer,
					 len, dtmf->sample_rate);

		if (!new_btn) {
			push_decoded(btn, &result, &consecutive_presses);
			i += samples_to_skip_on_silence;
			continue;
		}
		btn = new_btn;
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
char *dtmf_decode_frequency_domain(dtmf_t *dtmf)
{
	const size_t samples_to_skip_on_silence =
		decode_samples_to_skip_on_silence(dtmf->sample_rate);
	const size_t samples_to_skip_on_press =
		decode_samples_to_skip_on_press(dtmf->sample_rate);
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
	float target_amplitude = 0;

	size_t i = find_start_of_file(dtmf, buffer, len, &target_amplitude);

	dtmf_button_t *btn = NULL;
	size_t consecutive_presses = 0;
	uint32_t f1 = 0;
	uint32_t f2 = 0;
	while ((i + len) < dtmf->buffer.len) {
		if (is_silence((float *)dtmf->buffer.data + i, len,
			       target_amplitude)) {
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
static ssize_t find_start_of_file(dtmf_t *dtmf, cplx_t *buffer, size_t len,
				  float *amplitude)
{
	uint32_t f1 = 0, f2 = 0;
	size_t i = 0;

	/* First find the start of the file */
	while ((i + len) < dtmf->buffer.len) {
		float_to_cplx_t((float *)dtmf->buffer.data + i, buffer, len);

		int err = fft(buffer, len);
		if (err != 0) {
			printf("Error running fft\n");
			return -1;
		}
		extract_frequencies(buffer, len, dtmf->sample_rate, &f1, &f2);

		if (is_valid_frequency(f1) && is_valid_frequency(f2)) {
			/* Found the start of the file */
			*amplitude = get_amplitude(
				(float *)dtmf->buffer.data + i, len);

			*amplitude = *amplitude - (*amplitude / 10);
			printf("Using %g as silence amplitude threshold\n",
			       *amplitude);
			break;
		} else {
			i += len;
		}
	}
	return i;
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
static float calculate_correlation(const float *signal, size_t len,
				   uint16_t row_freq, uint16_t col_freq,
				   uint32_t sample_rate)
{
	float mean_signal = 0, mean_sine = 0;
	for (size_t i = 0; i < len; i++) {
		mean_signal += signal[i];
		mean_sine += s(1, row_freq, col_freq, i, sample_rate);
	}
	mean_signal /= len;
	mean_sine /= len;

	double numerator = 0, denom1 = 0, denom2 = 0;
	for (size_t i = 0; i < len; i++) {
		const double diff_signal = signal[i] - mean_signal;
		const double diff_sine =
			s(1, row_freq, col_freq, i, sample_rate) - mean_sine;
		numerator += diff_signal * diff_sine;
		denom1 += diff_signal * diff_signal;
		denom2 += diff_sine * diff_sine;
	}

	if (denom1 == 0.0 || denom2 == 0.0) {
		return 0.0f;
	}
	printf("%d %d Correlation %f\n", row_freq, col_freq,
	       numerator / (sqrt(denom1 * denom2)));

	return numerator / (sqrt(denom1 * denom2));
}

static dtmf_button_t *decode_button_frequency_domain(const float *signal,
						     cplx_t *buffer, size_t len,
						     uint32_t sample_rate)
{
	uint32_t f1, f2;
	float_to_cplx_t(signal, buffer, len);
	int err = fft(buffer, len);
	if (err != 0) {
		printf("Error running fft\n");
		return NULL;
	}
	extract_frequencies(buffer, len, sample_rate, &f1, &f2);

	if (!(is_valid_frequency(f1) && is_valid_frequency(f2))) {
		return NULL;
	}
	return dtmf_get_closest_button(f1, f2);
}
static dtmf_button_t *decode_button_time_domain(const float *signal,
						cplx_t *buffer, size_t len,
						uint32_t sample_rate)
{
	(void)buffer;
	(void)len;
	const size_t samples = 5 * (sample_rate / ROW_FREQUENCIES[0]);
	assert(samples <= len);

	int f1 = 0;
	int f2 = 0;
	float best_corr = 0;
	for (size_t i = 0; i < ARRAY_LEN(ROW_FREQUENCIES); ++i) {
		const uint16_t row_freq = ROW_FREQUENCIES[i];
		for (size_t j = 0; j < ARRAY_LEN(COL_FREQUENCIES); ++j) {
			const uint16_t col_freq = COL_FREQUENCIES[j];
			const float corr =
				calculate_correlation(signal, samples, row_freq,
						      col_freq, sample_rate);
			if (corr > best_corr) {
				f1 = row_freq;
				f2 = col_freq;
				best_corr = corr;
			}
		}
	}
	if (!f1 || !f2) {
		return NULL;
	}
	return dtmf_get_closest_button(f1, f2);
}
