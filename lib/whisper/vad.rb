require "shellwords"

module Whisper
  module VAD
    MIN_CHUNK_DURATION = 30

    class << self
      def detect_silences(path, noise_db: -30, min_duration: 0.5)
        output = `ffmpeg -i #{path.shellescape} -af "silencedetect=noise=#{noise_db}dB:d=#{min_duration}" -f null - 2>&1`

        silences = []
        pending_start = nil

        output.each_line do |line|
          if (m = line.match(/silence_start: ([\d.]+)/))
            pending_start = m[1].to_f
          elsif (m = line.match(/silence_end: ([\d.]+) \| silence_duration: ([\d.]+)/)) && pending_start
            silences << { start: pending_start, end: m[1].to_f, duration: m[2].to_f }
            pending_start = nil
          end
        end

        silences
      end

      def compute_chunks(duration, silences, target_duration)
        return [[0.0, duration]] if duration <= target_duration

        window = target_duration * 0.25
        chunks = []
        pos = 0.0

        while pos < duration
          chunk_end = pos + target_duration

          if chunk_end >= duration - MIN_CHUNK_DURATION
            chunks << [pos, duration]
            break
          end

          search_start = chunk_end - window
          search_end = chunk_end + window
          candidates = silences.select { |s| s[:start] >= search_start && s[:end] <= search_end }

          split_at = if candidates.any?
            best = candidates.max_by { |s| s[:duration] }
            best[:start] + best[:duration] / 2
          else
            chunk_end
          end

          chunks << [pos, split_at]
          pos = split_at
        end

        chunks
      end
    end
  end
end
