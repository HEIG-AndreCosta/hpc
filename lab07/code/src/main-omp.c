#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <omp.h>

#define MAX_KMER 100

typedef struct {
	int count;
	char kmer[MAX_KMER];
} KmerEntry;

typedef struct {
	KmerEntry *entries;
	size_t count;
	size_t capacity;
} KmerTable;

void init_kmer_table(KmerTable *table)
{
	table->count = 0;
	table->capacity = 1024;
	table->entries = malloc(sizeof(KmerEntry) * table->capacity);
}
void deinit_kmer_table(KmerTable *table)
{
	free(table->entries);
}

void add_kmer(KmerTable *table, const char *kmer, size_t k)
{
	for (int i = 0; i < table->count; i++) {
		if (memcmp(table->entries[i].kmer, kmer, k) == 0) {
			table->entries[i].count++;
			return;
		}
	}

	if (table->count >= table->capacity) {
		table->capacity = (table->capacity == 0) ? 1 :
							   table->capacity * 2;
		table->entries = realloc(table->entries,
					 table->capacity * sizeof(KmerEntry));
		if (!table->entries) {
			perror("Error reallocating memory for k-mer table");
			exit(1);
		}
	}

	memcpy(table->entries[table->count].kmer, kmer, k);
	table->entries[table->count].kmer[k] = '\0';
	table->entries[table->count].count = 1;
	table->count++;
}

void merge_kmer_table(KmerTable *dst, KmerTable *src)
{
	for (size_t i = 0; i < src->count; i++) {
		int found = 0;
		for (size_t j = 0; j < dst->count; j++) {
			if (strcmp(dst->entries[j].kmer,
				   src->entries[i].kmer) == 0) {
				dst->entries[j].count += src->entries[i].count;
				found = 1;
				break;
			}
		}
		if (!found) {
			if (dst->count >= dst->capacity) {
				dst->capacity = (dst->capacity == 0) ?
							1 :
							dst->capacity * 2;
				dst->entries = realloc(
					dst->entries,
					dst->capacity * sizeof(KmerEntry));
				if (!dst->entries) {
					perror("Error reallocating memory for merged table");
					exit(1);
				}
			}
			strcpy(dst->entries[dst->count].kmer,
			       src->entries[i].kmer);
			dst->entries[dst->count].count = src->entries[i].count;
			dst->count++;
		}
	}
}

int main(int argc, char **argv)
{
	if (argc != 3) {
		fprintf(stderr, "Usage: %s <input_file> <k>\n", argv[0]);
		return EXIT_FAILURE;
	}

	const char *input_file = argv[1];
	int k = atoi(argv[2]);

	if (k <= 0) {
		fprintf(stderr, "Error: k must be a positive integer.\n");
		return EXIT_FAILURE;
	}
	if (k > MAX_KMER) {
		fprintf(stderr, "Error: k must be < %d.\n", MAX_KMER);
		return EXIT_FAILURE;
	}

	FILE *file = fopen(input_file, "r");
	if (!file) {
		perror("Error opening file");
		return EXIT_FAILURE;
	}
	fseek(file, 0, SEEK_END);
	long file_size = ftell(file);
	fseek(file, 0, SEEK_SET);

	char *addr =
		mmap(NULL, file_size, PROT_READ, MAP_PRIVATE, fileno(file), 0);

	if (addr == MAP_FAILED) {
		perror("Error mmaping file");
		return EXIT_FAILURE;
	}
	size_t num_threads = omp_get_max_threads();
	KmerTable *tables = malloc(num_threads * sizeof(KmerTable));

#pragma omp parallel
	{
		size_t id = omp_get_thread_num();
		KmerTable *table = &tables[id];
		init_kmer_table(table);

#pragma omp for
		for (long i = 0; i <= file_size - k; i++) {
			add_kmer(table, &addr[i], k);
		}
	}
	munmap(addr, file_size);

	for (size_t i = 1; i < num_threads; ++i) {
		merge_kmer_table(&tables[0], &tables[i]);
	}

	printf("Results:\n");
	for (int i = 0; i < tables[0].count; i++) {
		printf("%s: %d\n", tables[0].entries[i].kmer,
		       tables[0].entries[i].count);
	}
	for (size_t i = 0; i < num_threads; ++i) {
		deinit_kmer_table(&tables[i]);
	}

	free(tables);
	fclose(file);
	return 0;
}
