#include <stdint.h>
#include <stdlib.h>

void writeMemSafe(void* address, uint32_t value)
{
  __sync_synchronize();
  *((uint32_t*)address) = value;
  __sync_synchronize();
}

uint32_t readMemSafe(void const* address)
{
  __sync_synchronize();
  uint32_t const value = *((uint32_t const*)address);
  __sync_synchronize();
  return value;
}
