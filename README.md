# whisper-ruby

Ruby client for [whisper.cpp](https://github.com/ggerganov/whisper.cpp) HTTP servers. Transcribes audio files with VAD-based chunking to prevent Whisper hallucination loops on long recordings.

## Usage

```ruby
require "whisper"

# Transcribe a short audio clip (< 2 minutes, no chunking)
text = Whisper.transcribe_short("voice_note.webm", language: "nl")

# Transcribe a long recording with VAD-based chunking
text = Whisper.transcribe("meeting.m4a", language: "nl")

# With timestamps
text = Whisper.transcribe("meeting.m4a", language: "nl", timestamps: true)

# Progress callback
Whisper.transcribe("meeting.m4a", language: "nl") do |i, total, start_time, end_time|
  puts "[#{i + 1}/#{total}] #{start_time}s - #{end_time}s"
end
```

### Configuration

```ruby
Whisper.configure do |c|
  c.base_url = "http://whisper-server.local:8081/inference"
  c.chunk_duration = 90 # seconds (default: 120)
end
```

Or via environment variable:

```bash
export WHISPER_URL="http://ollama.home:8081/inference"
```

## Requirements

- **ffmpeg** and **ffprobe** on PATH (for audio conversion and VAD)
- A running [whisper.cpp server](https://github.com/ggerganov/whisper.cpp/tree/master/examples/server)

## Installation

```bash
gem install whisper --source https://github.com/erikdebruijn/whisper-ruby
```

Or in a Gemfile:

```ruby
gem "whisper", github: "erikdebruijn/whisper-ruby"
```

## Running specs

```bash
bundle install
bundle exec rspec
```
