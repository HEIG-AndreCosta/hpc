#include "k-means.h"
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Function to initialize cluster centers using the k-means++ algorithm
void kmeans_pp(struct img_t *image, int num_clusters, uint8_t *centers)
{
	// Select a random pixel as the first cluster center
	int first_center_index =
		(rand() % (image->width * image->height)) * image->components;

	// Set the RGB values of the first center
	centers[0 + R_OFFSET] = image->data[first_center_index + R_OFFSET];
	centers[0 + G_OFFSET] = image->data[first_center_index + G_OFFSET];
	centers[0 + B_OFFSET] = image->data[first_center_index + B_OFFSET];

	uint32_t *distances = (uint32_t *)malloc(image->width * image->height *
						 sizeof(uint32_t));

	// Calculate distances from each pixel to the first center
	uint8_t *first_center = malloc(image->components * sizeof(uint8_t));
	memcpy(first_center, centers, image->components * sizeof(uint8_t));

	for (int i = 0; i < image->width * image->height; ++i) {
		uint8_t *src = image->data + i * image->components;
		distances[i] = distance_single_pixel(src, first_center);
	}

	// Loop to find remaining cluster centers
	for (int i = 1; i < num_clusters; ++i) {
		float total_weight = 0.0;

		// Calculate total weight (sum of distances)
		for (int j = 0; j < image->width * image->height; ++j) {
			total_weight += distances[j];
		}

		float r = ((float)rand() / (float)RAND_MAX) * total_weight;
		int index = 0;

		// Choose the next center based on weighted probability
		while (index < image->width * image->height &&
		       r > distances[index]) {
			r -= distances[index];
			index++;
		}

		// Set the RGB values of the selected center
		centers[i * image->components + R_OFFSET] =
			image->data[index * image->components + R_OFFSET];
		centers[i * image->components + G_OFFSET] =
			image->data[index * image->components + G_OFFSET];
		centers[i * image->components + B_OFFSET] =
			image->data[index * image->components + B_OFFSET];

		// Update distances based on the new center
		uint8_t *new_center = centers + i * image->components;

		for (size_t j = 0; j < image->width * image->height; j++) {
			uint8_t *src = image->data + j * image->components;

			uint32_t dist = distance_single_pixel(src, new_center);

			if (dist < distances[j]) {
				distances[j] = dist;
			}
		}
	}

	free(first_center);
	free(distances);
}

// This function performs k-means clustering on an image.
// It takes as input the image, its dimensions (width and height), and the number of clusters to find.
void kmeans(struct img_t *image, int num_clusters)
{
	uint8_t *centers =
		calloc(num_clusters * image->components, sizeof(uint8_t));

	// Initialize the cluster centers using the k-means++ algorithm.
	kmeans_pp(image, num_clusters, centers);

	int *assignments =
		(int *)malloc(image->width * image->height * sizeof(int));

	// Assign each pixel in the image to its nearest cluster.
	for (int i = 0; i < image->width * image->height; ++i) {
		float min_dist = INFINITY;
		int best_cluster = -1;

		uint8_t *src = image->data + i * image->components;

		for (int c = 0; c < num_clusters; c++) {
			uint8_t *dest = centers + c * image->components;

			float dist = distance_single_pixel(src, dest);

			if (dist < min_dist) {
				min_dist = dist;
				best_cluster = c;
			}
		}
		assignments[i] = best_cluster;
	}

	ClusterData *cluster_data =
		(ClusterData *)calloc(num_clusters, sizeof(ClusterData));

	// Compute the sum of the pixel values for each cluster.
	for (int i = 0; i < image->width * image->height; ++i) {
		int cluster = assignments[i];
		cluster_data[cluster].count++;
		cluster_data[cluster].sum_r +=
			(int)image->data[i * image->components + R_OFFSET];
		cluster_data[cluster].sum_g +=
			(int)image->data[i * image->components + G_OFFSET];
		cluster_data[cluster].sum_b +=
			(int)image->data[i * image->components + B_OFFSET];
	}

	// Update cluster centers based on the computed sums
	for (int c = 0; c < num_clusters; ++c) {
		if (cluster_data[c].count > 0) {
			centers[c * image->components + R_OFFSET] =
				cluster_data[c].sum_r / cluster_data[c].count;
			centers[c * image->components + G_OFFSET] =
				cluster_data[c].sum_g / cluster_data[c].count;
			centers[c * image->components + B_OFFSET] =
				cluster_data[c].sum_b / cluster_data[c].count;
		}
	}

	free(cluster_data);

	// Update image data with the cluster centers
	for (int i = 0; i < image->width * image->height; ++i) {
		int cluster = assignments[i];
		image->data[i * image->components + R_OFFSET] =
			centers[cluster * image->components + R_OFFSET];
		image->data[i * image->components + G_OFFSET] =
			centers[cluster * image->components + G_OFFSET];
		image->data[i * image->components + B_OFFSET] =
			centers[cluster * image->components + B_OFFSET];
	}

	free(assignments);
	free(centers);
}
