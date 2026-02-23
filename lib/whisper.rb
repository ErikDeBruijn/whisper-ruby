module Whisper
  class Error < StandardError; end

  class << self
    attr_writer :base_url, :diarize_url, :chunk_duration

    def base_url
      @base_url || ENV.fetch("WHISPER_URL", "http://ollama.home:8081/inference")
    end

    def diarize_url
      @diarize_url || ENV.fetch("DIARIZE_URL", "http://localhost:8100/diarize")
    end

    def chunk_duration
      @chunk_duration || 120
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
  end
end

require_relative "whisper/version"
require_relative "whisper/vad"
require_relative "whisper/client"
require_relative "whisper/diarization"
