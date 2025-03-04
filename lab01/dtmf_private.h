
#ifndef DTMF_PRIVATE_H
#define DTMF_PRIVATE_H
#include "dtmf.h"
#define CHAR_SOUND_DURATION		0.2
#define CHAR_PAUSE_DURATION		0.2
#define SAME_CHAR_PAUSE_DURATION	0.05

#define CHAR_SOUND_SAMPLES(sample_rate) (CHAR_SOUND_DURATION * (sample_rate))
#define CHAR_PAUSE_SAMPLES(sample_rate) (CHAR_PAUSE_DURATION * (sample_rate))
#define SAME_CHAR_PAUSE_SAMPLES(sample_rate) \
	(SAME_CHAR_PAUSE_DURATION * sample_rate)

size_t dtmf_get_times_to_push(size_t btn_nr, char value, size_t extra_presses);
char dtmf_decode_character(size_t button, size_t presses);
#endif
