module Whisper
  class Error < StandardError; end

  class << self
    attr_writer :base_url, :diarize_url, :chunk_duration,
                :profiles_path, :profile_threshold, :embed_url

    def base_url
      @base_url || ENV.fetch("WHISPER_URL", "http://ollama.home:8081/inference")
    end

    def diarize_url
      @diarize_url || ENV.fetch("DIARIZE_URL", "http://localhost:8100/diarize")
    end

    def chunk_duration
      @chunk_duration || 120
    end

    def profiles_path
      @profiles_path || ENV.fetch("WHISPER_PROFILES_PATH", File.expand_path("~/.whisper_profiles.json"))
    end

    def profile_threshold
      @profile_threshold || 0.70
    end

    def embed_url
      @embed_url || ENV.fetch("WHISPER_EMBED_URL") { diarize_url.sub(%r{/diarize\z}, "/embed") }
    end

    def configure
      yield self
    end

    def client
      @client ||= Client.new
    end

    def reset_client!
      @client = nil
    end

    def transcribe(...) = client.transcribe(...)
    def transcribe_short(...) = client.transcribe_short(...)
    def transcribe_with_speakers(...) = client.transcribe_with_speakers(...)
    def diarize(...) = Diarization.diarize(...)
    def learn_voiceprint(...) = VoiceProfile.learn_voiceprint(...)
  end
end

require_relative "whisper/version"
require_relative "whisper/vad"
require_relative "whisper/client"
require_relative "whisper/diarization"
require_relative "whisper/voice_profile"
