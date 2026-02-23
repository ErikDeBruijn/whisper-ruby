module Whisper
  class Error < StandardError; end

  class << self
    attr_writer :base_url, :chunk_duration

    def base_url
      @base_url || ENV.fetch("WHISPER_URL", "http://ollama.home:8081/inference")
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
  end
end

require_relative "whisper/version"
require_relative "whisper/vad"
require_relative "whisper/client"
