# frozen_string_literal: true

require_relative "lib/whisper/version"

Gem::Specification.new do |spec|
  spec.name = "whisper"
  spec.version = Whisper::VERSION
  spec.authors = ["Erik de Bruijn"]
  spec.email = ["erik@erikdebruijn.nl"]

  spec.summary = "Ruby client for Whisper speech-to-text servers"
  spec.description = "A Ruby client for whisper.cpp HTTP servers. Transcribe audio files with VAD-based chunking to avoid hallucination loops. Supports any audio format via ffmpeg."
  spec.homepage = "https://github.com/erikdebruijn/whisper-ruby"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.glob("lib/**/*") + %w[whisper.gemspec Gemfile LICENSE.txt README.md]
  spec.require_paths = ["lib"]
end
