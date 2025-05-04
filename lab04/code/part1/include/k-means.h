#include "image.h"

typedef struct {
	int count;
	int sum_r;
	int sum_g;
	int sum_b;
} ClusterData;

void distance_simd(const uint8_t *p1, const uint8_t *p2, uint32_t *result);
uint32_t distance_single_pixel(const uint8_t *p1, const uint8_t *p2);
void distance_four_pixels(const uint8_t *p1, const uint8_t *p2,
			  uint32_t *result);
void kmeans_pp(struct img_t *image, int num_clusters, uint8_t *centers);
void kmeans(struct img_t *image, int num_clusters);
