#include "image.h"

typedef struct {
	int count;
	int sum_r;
	int sum_g;
	int sum_b;
} ClusterData;

void distance_simd(uint8_t *p1, uint8_t *p2, uint32_t *result);
uint32_t distance_single_pixel(uint8_t *p1, uint8_t *p2);
void kmeans_pp(struct img_t *image, int num_clusters, uint8_t *centers);
void kmeans(struct img_t *image, int num_clusters);
