#include "engine/log.h"

#include <spdlog/pattern_formatter.h>
#include <spdlog/sinks/stdout_sinks.h>

#include <algorithm>
#include <cctype>
#include <cstddef>
#include <cstdint>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

namespace ingine::engine {
namespace {

// Cap on the in-memory ring (roughly the last few hundred INFO-level lines).
constexpr std::size_t kLogRingCapacity = 1000;

// %(levelname)s: Python's level names.
class LevelName final : public spdlog::custom_flag_formatter {
 public:
  void format(const spdlog::details::log_msg& msg, const std::tm&, spdlog::memory_buf_t& dest) override {
    std::string_view name;
    switch (msg.level) {
      case spdlog::level::trace:
      case spdlog::level::debug: name = "DEBUG"; break;
      case spdlog::level::info: name = "INFO"; break;
      case spdlog::level::warn: name = "WARNING"; break;
      case spdlog::level::err: name = "ERROR"; break;
      default: name = "CRITICAL"; break;
    }
    dest.append(name.data(), name.data() + name.size());
  }
  std::unique_ptr<custom_flag_formatter> clone() const override { return std::make_unique<LevelName>(); }
};

// Captures the formatted lines of the logger in a bounded ring (oldest dropped first) for the /logs
// endpoint. Formats the message exactly as the stderr sink does (its formatter is set from the logger).
class RingSink final : public spdlog::sinks::sink {
 public:
  void log(const spdlog::details::log_msg& msg) override {
    std::string line;
    if (formatter_) {
      spdlog::memory_buf_t formatted;
      formatter_->format(msg, formatted);
      line.assign(formatted.data(), formatted.size());
    } else {
      line.assign(msg.payload.data(), msg.payload.size());
    }
    std::lock_guard<std::mutex> lock(mutex_);
    if (lines_.size() >= kLogRingCapacity) lines_.erase(lines_.begin());
    lines_.push_back(std::move(line));
  }
  void flush() override {}
  void set_pattern(const std::string&) override {}
  void set_formatter(std::unique_ptr<spdlog::formatter> sink_formatter) override {
    formatter_ = std::move(sink_formatter);
  }
  // The most recent `max_lines` lines (oldest first).
  std::vector<std::string> recent(std::size_t max_lines) const {
    std::lock_guard<std::mutex> lock(mutex_);
    if (lines_.size() <= max_lines) return lines_;
    return std::vector<std::string>(lines_.end() - static_cast<std::ptrdiff_t>(max_lines), lines_.end());
  }

 private:
  std::unique_ptr<spdlog::formatter> formatter_;
  mutable std::mutex mutex_;
  std::vector<std::string> lines_;
};

std::shared_ptr<RingSink> make_ring_sink() { return std::make_shared<RingSink>(); }

std::shared_ptr<spdlog::logger> make_logger() {
  const auto ring = make_ring_sink();
  auto logger = std::make_shared<spdlog::logger>(
      "ingine.server",
      {std::make_shared<spdlog::sinks::stderr_sink_mt>(), ring});
  auto formatter = std::make_unique<spdlog::pattern_formatter>();
  formatter->add_flag<LevelName>('*').set_pattern("%Y-%m-%d %H:%M:%S,%e %* %n: %v");
  logger->set_formatter(std::move(formatter));
  logger->set_level(spdlog::level::info);
  logger->flush_on(spdlog::level::trace);
  return logger;
}

}  // namespace

spdlog::logger& server_log() {
  static const std::shared_ptr<spdlog::logger> logger = make_logger();
  return *logger;
}

bool set_log_level(std::string_view name) {
  std::string up(name);
  std::transform(up.begin(), up.end(), up.begin(), [](unsigned char c) { return std::toupper(c); });
  spdlog::level::level_enum level;
  if (up == "DEBUG") level = spdlog::level::debug;
  else if (up == "INFO") level = spdlog::level::info;
  else if (up == "WARNING" || up == "WARN") level = spdlog::level::warn;
  else if (up == "ERROR") level = spdlog::level::err;
  else if (up == "CRITICAL" || up == "FATAL") level = spdlog::level::critical;
  else if (up == "NOTSET") level = spdlog::level::trace;
  else return false;
  server_log().set_level(level);
  return true;
}

std::vector<std::string> recent_log_lines(std::size_t max_lines) {
  static const std::shared_ptr<RingSink> ring = [] {
    auto& l = server_log();
    for (const auto& s : l.sinks()) {
      if (auto r = std::dynamic_pointer_cast<RingSink>(s)) return r;
    }
    return std::shared_ptr<RingSink>{};
  }();
  if (!ring) return {};
  if (max_lines == 0) return {};
  // Never return an unbounded list: the sink caps the ring itself.
  if (max_lines > kLogRingCapacity) max_lines = kLogRingCapacity;
  return ring->recent(max_lines);
}

}  // namespace ingine::engine
