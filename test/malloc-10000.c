#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

int main(void) {
  printf("page size is: %d\n", getpagesize());
  int *ptr = NULL;
  for (unsigned int i = 1; i <= 25; i++)
    {
      if (ptr)
        free(ptr);
      printf("allocating %d MB\n", i);
      ptr = malloc(i * 1024 * 1024);
      sleep(3);
    }

  for (unsigned int i = 25; i >= 1; i--)
    {
      if (ptr)
        free(ptr);
      printf("allocating %d MB\n", i);
      ptr = malloc(i * 1024 * 1024);
      sleep(3);
    }
  
  free(ptr);
  return 0;
}
