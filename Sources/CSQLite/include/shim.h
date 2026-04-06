#pragma once
#include <sqlite3.h>

// Expose SQLITE_TRANSIENT / SQLITE_STATIC to Swift (C macros aren't bridged)
static inline sqlite3_destructor_type csqlite_transient(void) {
    return SQLITE_TRANSIENT;
}

static inline sqlite3_destructor_type csqlite_static(void) {
    return SQLITE_STATIC;
}
