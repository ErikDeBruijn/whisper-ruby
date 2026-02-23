require "json"
require "net/http"
require "shellwords"
require "tempfile"
require "fileutils"

module Whisper
  class Client
    SAMPLE_RATE = 16_000

    def initialize(base_url: nil)
      @base_url = base_url || Whisper.base_url
    end

    def transcribe(input_path, language: "auto", chunk_duration: nil, timestamps: false, on_progress: nil)
      chunk_duration ||= Whisper.chunk_duration
      duration = get_duration(input_path)
      silences = VAD.detect_silences(input_path)
      chunks = VAD.compute_chunks(duration, silences, chunk_duration)

      results = Dir.mktmpdir("whisper_") do |tmpdir|
        chunks.each_with_index.map do |(chunk_start, chunk_end), i|
          chunk_path = File.join(tmpdir, format("chunk_%03d.wav", i))
          chunk_length = chunk_end - chunk_start

          on_progress&.call(i, chunks.size, chunk_start, chunk_end)

          convert_to_wav(input_path, chunk_path, start: chunk_start, duration: chunk_length)
          text = send_to_whisper(chunk_path, language:)

          { start: chunk_start, end: chunk_end, text: text }
        end
      end

      format_results(results, timestamps:)
    end

    def transcribe_with_speakers(input_path, language: "auto",
                                  min_speakers: nil, max_speakers: nil, speaker_names: {},
                                  on_progress: nil)
      # 1. Diarize first — speaker segments are leading
      on_progress&.call(:diarize, 0, 1, 0.0, 0.0)
      diarization = Diarization.diarize(
        input_path,
        min_speakers: min_speakers,
        max_speakers: max_speakers
      )
      on_progress&.call(:diarize, 1, 1, 0.0, 0.0)

      # 2. Merge adjacent segments from same speaker to reduce whisper calls
      speaker_segments = Diarization.merge_adjacent(diarization[:segments])

      # 3. Transcribe each speaker segment
      results = Dir.mktmpdir("whisper_") do |tmpdir|
        speaker_segments.each_with_index.map do |seg, i|
          chunk_path = File.join(tmpdir, format("chunk_%03d.wav", i))
          chunk_length = seg[:end] - seg[:start]

          on_progress&.call(:transcribe, i, speaker_segments.size, seg[:start], seg[:end])

          convert_to_wav(input_path, chunk_path, start: seg[:start], duration: chunk_length)
          text = send_to_whisper(chunk_path, language:)

          {
            start: seg[:start],
            end: seg[:end],
            speaker: seg[:speaker],
            text: clean_repetitions(text)
          }
        end
      end

      results = Diarization.apply_speaker_names(results, speaker_names) if speaker_names.any?

      { speakers: diarization[:speakers], segments: results }
    end

    def transcribe_short(input_path, language: "auto")
      wav_path = "#{input_path}.wav"
      convert_to_wav(input_path, wav_path)
      send_to_whisper(wav_path, language:)
    ensure
      File.delete(wav_path) if wav_path && File.exist?(wav_path)
    end

    private

    def get_duration(path)
      output = `ffprobe -v quiet -show_entries format=duration -of csv=p=0 #{path.shellescape} 2>/dev/null`
      raise Error, "ffprobe failed for #{path}" if output.strip.empty?

      output.strip.to_f
    end

    def convert_to_wav(input_path, output_path, start: nil, duration: nil)
      cmd = ["ffmpeg", "-y", "-i", input_path]
      cmd += ["-ss", start.to_s] if start
      cmd += ["-t", duration.to_s] if duration
      cmd += ["-ar", SAMPLE_RATE.to_s, "-ac", "1", "-c:a", "pcm_s16le", output_path]

      system(*cmd, [:out, :err] => "/dev/null", exception: true)
    end

    def send_to_whisper(wav_path, language: "auto")
      uri = URI(@base_url)
      file = File.open(wav_path, "rb")

      form_data = [
        ["file", file, { filename: "audio.wav", content_type: "audio/wav" }],
        ["language", language],
        ["response_format", "json"]
      ]

      request = Net::HTTP::Post.new(uri)
      request.set_form(form_data, "multipart/form-data")

      response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 300) do |http|
        http.request(request)
      end

      file.close

      raise Error, "Whisper server returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

      data = JSON.parse(response.body)
      data["text"]&.strip || ""
    end

    def format_results(results, timestamps: false)
      parts = results.filter_map do |r|
        text = clean_repetitions(r[:text])
        next if text.empty?

        lines = []
        lines << "[#{format_time(r[:start])}-#{format_time(r[:end])}]" if timestamps
        lines << text
        lines << "" if timestamps
        lines.join("\n")
      end

      parts.join("\n").rstrip + "\n"
    end

    def clean_repetitions(text)
      sentences = text.split(/(?<=[.!?])\s+/)
      cleaned = []
      prev = nil
      repeat_count = 0

      sentences.each do |sentence|
        stripped = sentence.strip
        if stripped == prev && stripped.length > 10
          repeat_count += 1
          next if repeat_count > 1
        else
          repeat_count = 0
        end
        cleaned << sentence
        prev = stripped unless stripped.empty?
      end

      cleaned.join(" ")
    end

    def format_time(seconds)
      total = seconds.to_i
      m, s = total.divmod(60)
      h, m = m.divmod(60)
      h > 0 ? format("%d:%02d:%02d", h, m, s) : format("%d:%02d", m, s)
    end
  end
end
