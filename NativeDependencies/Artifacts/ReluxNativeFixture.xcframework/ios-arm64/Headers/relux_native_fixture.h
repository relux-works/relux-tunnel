#ifndef RELUX_NATIVE_FIXTURE_H
#define RELUX_NATIVE_FIXTURE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

uint32_t relux_native_fixture_schema_version(void);
uint32_t relux_native_fixture_mix(uint32_t value);

#ifdef __cplusplus
}
#endif

#endif
