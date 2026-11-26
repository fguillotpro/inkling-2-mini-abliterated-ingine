// The server's logger ("ingine.server") in Python logging's format:
// "%(asctime)s %(levelname)s %(name)s: %(message)s".
#pragma once

#include <spdlog/logger.h>

#include <cstddef>
#include <string>
#include <string_view>
#include <vector>

namespace ingine::engine {

spdlog::logger& server_log();

// Python logging level names (case-insensitive): DEBUG, INFO, WARNING/WARN, ERROR, CRITICAL/FATAL, NOTSET.
// Returns false (level unchanged) for anything else.
bool set_log_level(std::string_view name);

// The most recent server-log lines, oldest first, for the /logs endpoint. Never blocks the log path; the
// returned vector holds at most `max_lines` (fewer, if fewer lines have been logged so far).
std::vector<std::string> recent_log_lines(std::size_t max_lines = 200);

}  // namespace ingine::engine
