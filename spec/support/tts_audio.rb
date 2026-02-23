require "fileutils"
require "digest"

module TTSAudio
  CACHE_DIR = File.join(__dir__, "..", "fixtures", "audio")
  SAMPLE_RATE = 16_000

  class << self
    def generate_segment(text, voice: "Daniel", rate: 180)
      ensure_cache_dir
      key = Digest::SHA256.hexdigest("#{voice}:#{rate}:#{text}")[0, 12]
      wav_path = File.join(CACHE_DIR, "#{key}.wav")

      unless File.exist?(wav_path)
        aiff_path = "#{wav_path}.aiff"
        system("say", "-v", voice, "-r", rate.to_s, "-o", aiff_path, text, exception: true)
        system(
          "ffmpeg", "-y", "-i", aiff_path,
          "-ar", SAMPLE_RATE.to_s, "-ac", "1", "-c:a", "pcm_s16le",
          wav_path,
          [:out, :err] => "/dev/null",
          exception: true
        )
        File.delete(aiff_path)
      end

      wav_path
    end

    def generate_multispeaker(segments, silence_gap: 2.0)
      ensure_cache_dir
      key = Digest::SHA256.hexdigest(segments.inspect + silence_gap.to_s)[0, 12]
      output_path = File.join(CACHE_DIR, "multi_#{key}.wav")

      return output_path if File.exist?(output_path)

      segment_paths = segments.map do |seg|
        generate_segment(seg[:text], voice: seg[:voice], rate: seg.fetch(:rate, 180))
      end

      silence_path = File.join(CACHE_DIR, "silence_#{silence_gap}s.wav")
      unless File.exist?(silence_path)
        system(
          "ffmpeg", "-y",
          "-f", "lavfi", "-i", "anullsrc=r=#{SAMPLE_RATE}:cl=mono",
          "-t", silence_gap.to_s,
          "-c:a", "pcm_s16le", silence_path,
          [:out, :err] => "/dev/null",
          exception: true
        )
      end

      parts = []
      segment_paths.each_with_index do |path, i|
        parts << path
        parts << silence_path if i < segment_paths.size - 1
      end

      concat_list = File.join(CACHE_DIR, "concat_#{key}.txt")
      File.write(concat_list, parts.map { |p| "file '#{p}'" }.join("\n") + "\n")

      system(
        "ffmpeg", "-y", "-f", "concat", "-safe", "0", "-i", concat_list,
        "-c:a", "pcm_s16le", "-ar", SAMPLE_RATE.to_s, "-ac", "1",
        output_path,
        [:out, :err] => "/dev/null",
        exception: true
      )
      File.delete(concat_list)

      output_path
    end

    def text_similarity(expected, actual)
      expected_words = normalize(expected).split
      actual_words = normalize(actual).split

      return 0.0 if expected_words.empty?

      matches = expected_words.count { |w| actual_words.include?(w) }
      matches.to_f / expected_words.size
    end

    private

    def ensure_cache_dir
      FileUtils.mkdir_p(CACHE_DIR)
    end

    def normalize(text)
      text.downcase.gsub(/[^a-z0-9\s]/, "").gsub(/\s+/, " ").strip
    end
  end
end
