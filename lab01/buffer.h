
#ifndef BUFFER_H
#define BUFFER_H

#include <stddef.h>

typedef struct {
	float *data;
	size_t capacity;
	size_t len;
} buffer_t;

int buffer_init(buffer_t *buffer, size_t capacity);
void buffer_construct(buffer_t *buffer, float *data, size_t capacity,
		      size_t len);
int buffer_push(buffer_t *buffer, float val);
void buffer_terminate(buffer_t *buffer);

#endif
