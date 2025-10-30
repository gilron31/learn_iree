#include "src/func_a.h"

int func_a(const int *arr, size_t size, int factor) {
  int rv = 0;
  for (size_t i = 0; i < size; ++i) {
    rv += arr[i];
    rv *= factor;
  }
  return rv;
}