#ifndef STREMIO_NATIVE_TORRENT_H
#define STREMIO_NATIVE_TORRENT_H
#include <stdint.h>
#ifdef __cplusplus
extern "C" {
#endif
void *st_session_create(const char *resume_directory);
void st_session_destroy(void *engine);
char *st_add_magnet(void *engine, const char *magnet, const char *save_path);
char *st_add_file(void *engine, const char *torrent_path, const char *save_path);
char *st_snapshot(void *engine);
char *st_set_paused(void *engine, const char *hash, int paused);
char *st_remove(void *engine, const char *hash);
char *st_select_file(void *engine, const char *hash, int file_index);
int st_range_ready(void *engine, const char *hash, int file_index, int64_t offset, int64_t length);
void st_prioritize_range(void *engine, const char *hash, int file_index, int64_t offset, int64_t length);
void st_save_resume(void *engine);
void st_free_string(char *value);
#ifdef __cplusplus
}
#endif
#endif
