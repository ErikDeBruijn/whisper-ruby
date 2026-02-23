# whisper-ruby

Ruby client for [whisper.cpp](https://github.com/ggerganov/whisper.cpp) HTTP servers. Transcribes audio files with VAD-based chunking to prevent Whisper hallucination loops on long recordings. Optional speaker diarization via included server.

## Usage

```ruby
require "whisper"

# Transcribe a short audio clip (< 2 minutes, no chunking)
text = Whisper.transcribe_short("voice_note.webm", language: "nl")

# Transcribe a long recording with VAD-based chunking
text = Whisper.transcribe("meeting.m4a", language: "nl")

# With timestamps
text = Whisper.transcribe("meeting.m4a", language: "nl", timestamps: true)
```

### Speaker diarization

Requires the included `diarize-server` to be running (see below).

```ruby
result = Whisper.transcribe_with_speakers(
  "meeting.m4a",
  language: "nl",
  min_speakers: 2,
  speaker_names: { "SPEAKER_00" => "Erik", "SPEAKER_01" => "Steinar" }
)

result[:segments].each do |seg|
  puts "[#{seg[:speaker]}] #{seg[:text]}"
end
```

### Configuration

```ruby
Whisper.configure do |c|
  c.base_url = "http://whisper-server.local:8081/inference"
  c.diarize_url = "http://localhost:8100/diarize"
  c.chunk_duration = 90 # seconds (default: 120)
end
```

Or via environment variables:

```bash
export WHISPER_URL="http://ollama.home:8081/inference"
export DIARIZE_URL="http://localhost:8100/diarize"
```

## Diarization server

A lightweight speaker diarization server using SpeechBrain ECAPA-TDNN embeddings. No HuggingFace gated model access required.

```bash
# Install Python dependencies
pip install speechbrain torchaudio scipy

# Start the server
./diarize-server                    # CPU, port 8100
./diarize-server --device mps       # Apple Silicon GPU
./diarize-server --device cuda      # NVIDIA GPU
```

The server provides a single endpoint:

```bash
curl -X POST http://localhost:8100/diarize \
  -F "file=@meeting.wav" \
  -F "min_speakers=2"
# Returns: {"speakers": 3, "segments": [{"start": 0.0, "end": 3.5, "speaker": "SPEAKER_00"}, ...]}
```

### How diarization works

1. **VAD** — ffmpeg `silencedetect` finds speech vs. silence boundaries
2. **Embeddings** — SpeechBrain ECAPA-TDNN extracts a 192-dim voice vector per segment
3. **Clustering** — Agglomerative clustering groups segments by speaker similarity
4. **Labeling** — Anonymous labels (SPEAKER_00, SPEAKER_01) assigned in order of appearance
5. **Merge** — Speaker labels are mapped onto transcription chunks by timestamp overlap

## Requirements

- **ffmpeg** and **ffprobe** on PATH (for audio conversion and VAD)
- A running [whisper.cpp server](https://github.com/ggerganov/whisper.cpp/tree/master/examples/server)
- For diarization: Python with speechbrain, torchaudio, scipy

## Installation

```ruby
gem "whisper", github: "erikdebruijn/whisper-ruby"
```

## Running specs

```bash
bundle install
bundle exec rspec              # unit specs only (17 examples)
RUN_E2E=1 bundle exec rspec   # includes E2E specs (requires running servers)
```

E2E specs generate test audio via macOS TTS (`say`), send it to Whisper and the diarize-server, and verify the roundtrip. They require both `WHISPER_URL` and `DIARIZE_URL` servers to be running.
