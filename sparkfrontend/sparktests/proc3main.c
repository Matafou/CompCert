#include <stdio.h>

void proc3(int * arg);


int main(int argc, char ** argv)
{
  int n=3;
  proc3(&n);
  printf(" \n == %d", n);
  return 0;
}
