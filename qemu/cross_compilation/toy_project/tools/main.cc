#include "src/func_a.h"
#include <cassert>
#include <iostream>
#include <vector>

int main(int argc, char *argv[]) {
  std::cout << "Welcome!" << std::endl;

  assert(argc == 2);
  int factor = std::stoi(argv[1]);

  std::cout << "Factor: " << factor << std::endl;

  std::vector<int> arr = {1, 0, 1, 1, 1};
  int res = func_a(arr.data(), arr.size(), factor);

  std::cout << "Res: " << res << std::endl;
}