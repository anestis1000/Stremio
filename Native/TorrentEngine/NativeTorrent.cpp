#include "include/NativeTorrent.h"
#include <libtorrent/session.hpp>
#include <libtorrent/session_params.hpp>
#include <libtorrent/add_torrent_params.hpp>
#include <libtorrent/torrent_info.hpp>
#include <libtorrent/torrent_status.hpp>
#include <libtorrent/magnet_uri.hpp>
#include <libtorrent/alert_types.hpp>
#include <libtorrent/read_resume_data.hpp>
#include <libtorrent/write_resume_data.hpp>
#include <libtorrent/download_priority.hpp>
#include <fstream>
#include <sstream>
#include <filesystem>
#include <thread>
#include <cstring>

namespace lt = libtorrent;
namespace fs = std::filesystem;
namespace {
std::string jsonString(std::string const& value) {
    std::string out = "\"";
    for (unsigned char c : value) {
        if (c == '"' || c == '\\') { out += '\\'; out += c; }
        else if (c == '\n') out += "\\n";
        else if (c == '\r') out += "\\r";
        else if (c == '\t') out += "\\t";
        else if (c < 32) out += ' ';
        else out += c;
    }
    return out + '"';
}
char *result(std::string const& value) { return strdup(value.c_str()); }
char *failure(std::string const& message) { return result("{\"error\":" + jsonString(message) + "}"); }
std::string hex(lt::sha1_hash const& hash) {
    static char const digits[] = "0123456789abcdef"; std::string out;
    for (int i = 0; i < 20; ++i) { auto c = static_cast<unsigned char>(hash[i]); out += digits[c >> 4]; out += digits[c & 15]; }
    return out;
}
lt::sha1_hash parseHash(std::string const& value) {
    if (value.size() != 40) throw std::runtime_error("Invalid torrent hash");
    auto digit = [](char c) -> int { if (c >= '0' && c <= '9') return c - '0'; if (c >= 'a' && c <= 'f') return c - 'a' + 10; if (c >= 'A' && c <= 'F') return c - 'A' + 10; throw std::runtime_error("Invalid torrent hash"); };
    lt::sha1_hash hash;
    for (int i = 0; i < 20; ++i) hash[i] = static_cast<char>((digit(value[i * 2]) << 4) | digit(value[i * 2 + 1]));
    return hash;
}
lt::settings_pack settings() {
    lt::settings_pack pack;
    pack.set_str(lt::settings_pack::user_agent, "Stremio-iOS/1.0 libtorrent/2.0.11");
    pack.set_str(lt::settings_pack::listen_interfaces, "0.0.0.0:0,[::]:0");
    pack.set_bool(lt::settings_pack::enable_dht, true);
    pack.set_bool(lt::settings_pack::enable_lsd, false);
    pack.set_bool(lt::settings_pack::enable_upnp, false);
    pack.set_bool(lt::settings_pack::enable_natpmp, false);
    pack.set_int(lt::settings_pack::connections_limit, 100);
    pack.set_int(lt::settings_pack::aio_threads, 2);
    return pack;
}
struct Engine {
    std::string resumeDirectory;
    lt::session session;
    explicit Engine(std::string directory) : resumeDirectory(std::move(directory)), session(settings()) { fs::create_directories(resumeDirectory); }
    lt::torrent_handle handle(char const* hash) {
        auto h = session.find_torrent(parseHash(hash));
        if (!h.is_valid()) throw std::runtime_error("Torrent is no longer available");
        return h;
    }
    void alerts() {
        std::vector<lt::alert*> list; session.pop_alerts(&list);
        for (auto *alert : list) {
            if (auto *saved = lt::alert_cast<lt::save_resume_data_alert>(alert)) {
                auto data = lt::write_resume_data_buf(saved->params);
                auto target = fs::path(resumeDirectory) / (hex(saved->params.info_hashes.v1) + ".resume");
                auto temp = target; temp += ".tmp";
                std::ofstream file(temp, std::ios::binary); file.write(data.data(), data.size()); file.close();
                fs::rename(temp, target);
            }
        }
    }
    char *add(lt::add_torrent_params params, char const* savePath) {
        auto hash = params.info_hashes.has_v1() ? params.info_hashes.v1 : params.ti->info_hashes().v1;
        auto hashText = hex(hash);
        auto path = fs::path(resumeDirectory) / (hashText + ".resume");
        if (fs::exists(path)) {
            std::ifstream file(path, std::ios::binary); std::vector<char> bytes((std::istreambuf_iterator<char>(file)), {});
            lt::error_code error; auto restored = lt::read_resume_data(bytes, error);
            if (!error) { if (!restored.ti) restored.ti = params.ti; restored.trackers.insert(restored.trackers.end(), params.trackers.begin(), params.trackers.end()); params = std::move(restored); }
        }
        params.save_path = savePath;
        params.flags &= ~lt::torrent_flags::auto_managed;
        params.flags &= ~lt::torrent_flags::paused;
        params.flags |= lt::torrent_flags::sequential_download;
        params.flags |= lt::torrent_flags::duplicate_is_error;
        lt::error_code error; auto handle = session.add_torrent(params, error);
        if (error == lt::errors::duplicate_torrent) handle = session.find_torrent(hash);
        else if (error) return failure(error.message());
        handle.resume(); return result("{\"id\":" + jsonString(hashText) + "}");
    }
};
}
extern "C" {
void *st_session_create(char const* directory) { try { return new Engine(directory); } catch (...) { return nullptr; } }
void st_session_destroy(void *p) { delete static_cast<Engine*>(p); }
void st_free_string(char *p) { free(p); }
char *st_add_magnet(void *p, char const* uri, char const* save) {
    try { lt::error_code error; auto params = lt::parse_magnet_uri(uri, error); if (error) return failure(error.message()); if (!params.info_hashes.has_v1()) return failure("This build requires a BitTorrent v1 or hybrid magnet"); return static_cast<Engine*>(p)->add(std::move(params), save); }
    catch (std::exception const& e) { return failure(e.what()); }
}
char *st_add_file(void *p, char const* path, char const* save) {
    try { lt::error_code error; lt::add_torrent_params params; params.ti = std::make_shared<lt::torrent_info>(path, error); if (error) return failure(error.message()); if (!params.ti->info_hashes().has_v1()) return failure("This build requires a BitTorrent v1 or hybrid torrent"); params.info_hashes = params.ti->info_hashes(); return static_cast<Engine*>(p)->add(std::move(params), save); }
    catch (std::exception const& e) { return failure(e.what()); }
}
char *st_snapshot(void *p) {
    try {
        auto &engine = *static_cast<Engine*>(p); engine.alerts(); std::ostringstream out; out << '['; bool first = true;
        for (auto h : engine.session.get_torrents()) {
            auto s = h.status(); auto ti = h.torrent_file();
            if (!first) out << ','; first = false;
            out << "{\"id\":" << jsonString(hex(h.info_hashes().v1)) << ",\"name\":" << jsonString(s.name)
                << ",\"progress\":" << s.progress << ",\"downloadRate\":" << s.download_payload_rate
                << ",\"downloaded\":" << s.total_wanted_done << ",\"total\":" << s.total_wanted << ",\"peers\":" << s.num_peers
                << ",\"paused\":" << ((s.flags & lt::torrent_flags::paused) ? "true" : "false")
                << ",\"finished\":" << (s.is_finished ? "true" : "false") << ",\"metadata\":" << (ti ? "true" : "false")
                << ",\"error\":" << jsonString(s.errc ? s.errc.message() : "") << ",\"files\":[";
            if (ti) {
                std::vector<std::int64_t> progress; h.file_progress(progress); auto const& files = ti->files();
                for (int i = 0; i < files.num_files(); ++i) {
                    auto index = lt::file_index_t{i}; if (i) out << ',';
                    out << "{\"index\":" << i << ",\"path\":" << jsonString(files.file_path(index)) << ",\"bytes\":" << files.file_size(index)
                        << ",\"downloaded\":" << (i < static_cast<int>(progress.size()) ? progress[i] : 0) << '}';
                }
            }
            out << "]}";
        }
        out << ']'; return result(out.str());
    } catch (std::exception const& e) { return failure(e.what()); }
}
char *st_set_paused(void *p, char const* hash, int paused) {
    try { auto h = static_cast<Engine*>(p)->handle(hash); if (paused) h.pause(); else h.resume(); return result("{}"); } catch (std::exception const& e) { return failure(e.what()); }
}
char *st_remove(void *p, char const* hash) {
    try { auto &engine = *static_cast<Engine*>(p); engine.session.remove_torrent(engine.handle(hash)); fs::remove(fs::path(engine.resumeDirectory) / (std::string(hash) + ".resume")); return result("{}"); } catch (std::exception const& e) { return failure(e.what()); }
}
char *st_select_file(void *p, char const* hash, int index) {
    try {
        auto h = static_cast<Engine*>(p)->handle(hash); auto ti = h.torrent_file();
        if (!ti || index < 0 || index >= ti->num_files()) return failure("File metadata is not available");
        std::vector<lt::download_priority_t> priorities(ti->num_files(), lt::dont_download);
        priorities[index] = lt::top_priority; h.prioritize_files(priorities); h.set_flags(lt::torrent_flags::sequential_download);
        return result("{}");
    } catch (std::exception const& e) { return failure(e.what()); }
}
int st_range_ready(void *p, char const* hash, int index, int64_t offset, int64_t length) {
    try {
        auto h = static_cast<Engine*>(p)->handle(hash); auto ti = h.torrent_file();
        if (!ti || index < 0 || index >= ti->num_files() || offset < 0 || length <= 0) return -1;
        auto const& files = ti->files(); auto file = lt::file_index_t{index};
        if (offset > files.file_size(file) || length > files.file_size(file) - offset) return -1;
        auto start = files.file_offset(file) + offset; auto end = start + length - 1;
        for (int64_t i = start / ti->piece_length(); i <= end / ti->piece_length(); ++i)
            if (!h.have_piece(lt::piece_index_t{static_cast<int>(i)})) return 0;
        return 1;
    } catch (...) { return -1; }
}
void st_prioritize_range(void *p, char const* hash, int index, int64_t offset, int64_t length) {
    try {
        auto h = static_cast<Engine*>(p)->handle(hash); auto ti = h.torrent_file();
        if (!ti || index < 0 || index >= ti->num_files() || offset < 0 || length <= 0) return;
        auto file = lt::file_index_t{index}; auto const& files = ti->files();
        auto start = files.file_offset(file) + offset;
        auto end = files.file_offset(file) + std::min(files.file_size(file), offset + length) - 1;
        int deadline = 0;
        for (int64_t i = start / ti->piece_length(); i <= end / ti->piece_length() && deadline < 3000; ++i, deadline += 30)
            h.set_piece_deadline(lt::piece_index_t{static_cast<int>(i)}, deadline);
    } catch (...) { }
}
void st_save_resume(void *p) {
    try {
        auto &engine = *static_cast<Engine*>(p);
        for (auto h : engine.session.get_torrents()) h.save_resume_data(lt::torrent_handle::save_info_dict | lt::torrent_handle::flush_disk_cache);
        for (int i = 0; i < 30; ++i) { engine.session.wait_for_alert(lt::milliseconds(50)); engine.alerts(); }
    } catch (...) { }
}
}
