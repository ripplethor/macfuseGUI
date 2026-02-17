#ifndef LIBSSH2_BRIDGE_H
#define LIBSSH2_BRIDGE_H

/*
 BEGINNER FILE GUIDE
 Layer: Native C bridge layer for browser transport
 Purpose:
 - Expose a small, stable C API that Swift can call for libssh2 SFTP operations.
 - Keep C memory ownership explicit so Swift can free returned buffers safely.
 - Provide timeout-bounded operations so browse calls do not hang forever.

 Ownership rules:
 - Any char* returned via out_error_message must be freed with macfusegui_libssh2_free_error.
 - Any list result allocated buffers must be released with macfusegui_libssh2_free_list_result.
 - Session handles returned from open_session must be closed with macfusegui_libssh2_close_session.
*/

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct macfusegui_libssh2_entry {
    /* Directory/file entry name (UTF-8, heap allocated). */
    char *name;
    /* 1 if entry is directory, 0 otherwise. */
    uint8_t is_directory;
    /* Optional attribute flags indicate whether metadata exists. */
    uint8_t has_size;
    uint8_t has_modified_at;
    /* Size and modified timestamp are meaningful only when corresponding flags are set. */
    uint64_t size_bytes;
    int64_t modified_at_unix;
} macfusegui_libssh2_entry;

typedef struct macfusegui_libssh2_list_result {
    /* status_code == 0 means success. Negative values are categorized bridge/libssh2 errors. */
    int32_t status_code;
    /* End-to-end operation latency in milliseconds (best-effort measurement). */
    int32_t latency_ms;
    /* Number of entries in entries array. */
    int32_t entry_count;
    /* Canonical path returned by server (for path normalization in Swift). */
    char *resolved_path;
    /* Human-readable error message (allocated) when status_code != 0. */
    char *error_message;
    /* Entry array (allocated). */
    macfusegui_libssh2_entry *entries;
} macfusegui_libssh2_list_result;

typedef struct macfusegui_libssh2_session_handle {
    /* Open TCP socket descriptor. */
    int sock;
    /* Opaque libssh2 session pointer. */
    void *session;
    /* Opaque libssh2 sftp pointer. */
    void *sftp;
} macfusegui_libssh2_session_handle;

/* Returns bridge version integer for compatibility checks. */
int32_t macfusegui_libssh2_bridge_version(void);

/*
 Opens persistent SSH + SFTP session.
 timeout_seconds applies to connect/handshake/auth/init deadline windows.
 On success: returns 0 and sets out_session.
 On failure: returns non-zero and sets out_error_message (caller frees with free_error).
*/
int32_t macfusegui_libssh2_open_session(
    const char *host,
    int32_t port,
    const char *username,
    const char *password,
    const char *private_key_path,
    int32_t timeout_seconds,
    macfusegui_libssh2_session_handle **out_session,
    char **out_error_message
);

/*
 Lists directories using an already-open session.
 remote_path should be normalized by caller.
 On success: out_result contains entries and possibly resolved_path.
 Caller must free out_result with macfusegui_libssh2_free_list_result.
*/
int32_t macfusegui_libssh2_list_directories_with_session(
    macfusegui_libssh2_session_handle *session,
    const char *remote_path,
    int32_t timeout_seconds,
    macfusegui_libssh2_list_result *out_result
);

/*
 Lightweight health probe for existing session.
 Used by keepalive loops in Swift actor.
*/
int32_t macfusegui_libssh2_ping_session(
    macfusegui_libssh2_session_handle *session,
    const char *remote_path,
    int32_t timeout_seconds,
    char **out_error_message
);

/* Closes session and releases native resources. Safe to call with NULL. */
void macfusegui_libssh2_close_session(macfusegui_libssh2_session_handle *session);

/* Frees error string returned by bridge out_error_message APIs. */
void macfusegui_libssh2_free_error(char *error_message);

/*
 One-shot helper: open session, list directories, close session.
 Useful for testing/compatibility paths.
*/
int32_t macfusegui_libssh2_list_directories(
    const char *host,
    int32_t port,
    const char *username,
    const char *password,
    const char *private_key_path,
    const char *remote_path,
    int32_t timeout_seconds,
    macfusegui_libssh2_list_result *out_result
);

/*
 Directory classifier helper used by tests/Swift parser compatibility checks.
 Returns 1 when entry is treated as directory, 0 otherwise.
*/
int32_t macfusegui_libssh2_classify_directory_entry(
    uint64_t attrs_flags,
    uint64_t permissions,
    const char *long_entry
);

/* Frees all allocated buffers inside result and resets fields to safe defaults. */
void macfusegui_libssh2_free_list_result(macfusegui_libssh2_list_result *result);

#ifdef __cplusplus
}
#endif

#endif /* LIBSSH2_BRIDGE_H */
