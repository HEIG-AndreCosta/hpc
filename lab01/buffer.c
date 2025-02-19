
#include "buffer.h"

#include <stdlib.h>
#include <string.h>
static int reallocate(buffer_t *buffer);

int buffer_init(buffer_t *buffer, size_t capacity)
{
	double *ptr = malloc(sizeof(*ptr) * capacity);
	if (!ptr) {
		return -1;
	}
	buffer->capacity = capacity;
	buffer->data = ptr;
	buffer->len = 0;
	return 0;
}
int buffer_push(buffer_t *buffer, double val)
{
	if (buffer->len >= buffer->capacity) {
		if (reallocate(buffer) < 0) {
			return -1;
		}
	}

	buffer->data[buffer->len++] = val;
	return 0;
}
void buffer_terminate(buffer_t *buffer)
{
	free(buffer->data);
	buffer->data = NULL;
	buffer->capacity = 0;
	buffer->len = 0;
}

static int reallocate(buffer_t *buffer)
{
	size_t new_capacity = buffer->capacity * 2;
	double *ptr = realloc(buffer->data, new_capacity);
	if (!ptr) {
		return -1;
	}
	buffer->data = ptr;
	buffer->capacity = new_capacity;
	return 0;
}
