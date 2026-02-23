require "json"
require "net/http"
require "shellwords"

module Whisper
  module Diarization
    class << self
      def diarize(audio_path, min_speakers: nil, max_speakers: nil, threshold: 0.6)
        uri = URI(Whisper.diarize_url)

        file = File.open(audio_path, "rb")
        form_data = [
          ["file", file, { filename: File.basename(audio_path), content_type: "audio/wav" }]
        ]
        form_data << ["min_speakers", min_speakers.to_s] if min_speakers
        form_data << ["max_speakers", max_speakers.to_s] if max_speakers
        form_data << ["threshold", threshold.to_s]

        request = Net::HTTP::Post.new(uri)
        request.set_form(form_data, "multipart/form-data")

        response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 600) do |http|
          http.request(request)
        end

        file.close

        raise Error, "Diarization server returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        JSON.parse(response.body, symbolize_names: true)
      end

      def merge(transcription_chunks, diarization_segments)
        return [] if diarization_segments.empty?

        merged = []

        transcription_chunks.each do |chunk|
          chunk_text = chunk[:text]
          chunk_start = chunk[:start]
          chunk_end = chunk[:end]

          # Find overlapping diarization segments
          overlapping = diarization_segments.select do |seg|
            seg[:start] < chunk_end && seg[:end] > chunk_start
          end

          if overlapping.empty?
            merged << { start: chunk_start, end: chunk_end, speaker: nil, text: chunk_text }
            next
          end

          # Assign speaker with most overlap
          best = overlapping.max_by do |seg|
            overlap_start = [chunk_start, seg[:start]].max
            overlap_end = [chunk_end, seg[:end]].min
            overlap_end - overlap_start
          end

          merged << { start: chunk_start, end: chunk_end, speaker: best[:speaker], text: chunk_text }
        end

        merged
      end

      def merge_adjacent(segments, max_gap: 2.0)
        return segments if segments.empty?

        merged = [segments.first.dup]

        segments[1..].each do |seg|
          prev = merged.last
          if seg[:speaker] == prev[:speaker] && (seg[:start] - prev[:end]) <= max_gap
            prev[:end] = seg[:end]
          else
            merged << seg.dup
          end
        end

        merged
      end

      def apply_speaker_names(segments, names)
        segments.map do |seg|
          named_speaker = names[seg[:speaker]] || seg[:speaker]
          seg.merge(speaker: named_speaker)
        end
      end
    end
  end
end
