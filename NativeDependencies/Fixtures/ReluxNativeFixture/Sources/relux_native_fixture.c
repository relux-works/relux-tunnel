#include "relux_native_fixture.h"

uint32_t relux_native_fixture_schema_version(void)
{
    return 1U;
}

uint32_t relux_native_fixture_mix(uint32_t value)
{
    return value ^ 0x524C5854U;
}
