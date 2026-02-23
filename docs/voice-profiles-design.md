# Voice Profile System Design

## Overview

Voice profiles enable automatic speaker identification during diarization. Instead of manually mapping `SPEAKER_00 => "Erik"`, stored reference embeddings are compared against diarization cluster centroids to resolve identities automatically.

## How It Works

1. **Enrollment**: Extract ECAPA-TDNN embeddings from a sample audio clip of a known speaker
2. **Storage**: Store reference embeddings (192-dim float arrays) in a JSON file
3. **Matching**: After diarization, compare each anonymous speaker's cluster centroid against stored profiles using cosine similarity
4. **Resolution**: Replace anonymous labels with known names when similarity exceeds threshold (default: 0.70)

## Storage Format

One JSON file per profile library. Default location: `~/.whisper_profiles.json`.

```json
{
  "version": 1,
  "profiles": [
    {
      "name": "Erik",
      "created_at": "2026-02-23T10:00:00Z",
      "updated_at": "2026-02-23T10:00:00Z",
      "embeddings": [
        [0.021, -0.043, 0.112, "... 192 floats"],
        [0.019, -0.039, 0.118, "... 192 floats"]
      ],
      "notes": "Recorded in office, good mic"
    }
  ]
}
```

Multiple embeddings per person handle voice variation across recording conditions (phone vs. in-person, different mics, tired voice). 3-5 samples from varied conditions is practical.

## Matching Algorithm

```
For each anonymous speaker cluster:
  centroid = mean of all segment embeddings in cluster

  For each stored profile:
    score = max cosine_similarity(centroid, ref) for ref in profile.embeddings

  Sort (cluster, profile) pairs by confidence descending
  Greedy assignment: each profile matched to at most one cluster

  If best_score >= threshold: resolve to profile name
  Otherwise: keep anonymous label
```

Greedy one-to-one assignment prevents two clusters matching the same profile.

## Ruby API

### Enrollment

```ruby
Whisper::VoiceProfile.enroll("Erik", "/path/to/sample.wav")
Whisper::VoiceProfile.enroll("Erik", "/path/to/phone_call.wav", notes: "Phone call")
```

### Integration with transcription

```ruby
result = Whisper.transcribe_with_speakers(
  "meeting.m4a",
  language: "nl",
  voice_profiles: Whisper::VoiceProfile.library
)

result[:segments].each do |seg|
  puts "[#{seg[:speaker]}] #{seg[:text]}"  # "Erik", "Steinar", or "SPEAKER_02"
end
```

Priority chain: profile match > manual `speaker_names` override > anonymous label.

### Other methods

```ruby
Whisper::VoiceProfile.all                    # list profiles
Whisper::VoiceProfile.remove("Erik")         # delete profile
Whisper::VoiceProfile.identify(embedding)    # match single embedding
Whisper::VoiceProfile.resolve(speaker_embeddings, threshold: 0.70)  # match all
Whisper::VoiceProfile.similarity("Erik", "/path/to/test.wav")       # calibration
```

### Configuration

```ruby
Whisper.configure do |c|
  c.profiles_path = "~/.whisper_profiles.json"
  c.profile_threshold = 0.70
end
```

## Server Changes Required

### New endpoint: `POST /embed`

Returns embeddings for an audio file without clustering:

```json
{"embeddings": [[0.02, -0.04, ...], ...], "mean": [0.021, ...]}
```

### Modified `/diarize` response

Add `speaker_embeddings` field with cluster centroids:

```json
{
  "speakers": 2,
  "segments": [...],
  "speaker_embeddings": {
    "SPEAKER_00": [0.021, -0.043, ...],
    "SPEAKER_01": [-0.011, 0.077, ...]
  }
}
```

## Edge Cases

- **Voice variation**: Multiple enrollment samples per person, max-over-all matching
- **Unknown speakers**: Below-threshold clusters stay anonymous, prompt for enrollment
- **Similar voices**: Greedy one-to-one assignment prevents double-matching
- **Short samples**: Enforce minimum 5-10 seconds for enrollment
- **Threshold calibration**: `similarity()` method lets users verify their threshold

## Implementation Sequence

1. **Server**: Add `/embed` endpoint and `speaker_embeddings` to `/diarize` response
2. **Ruby**: `VoiceProfileLibrary` (JSON store), `VoiceProfile` module, cosine similarity
3. **Ruby**: Integration into `transcribe_with_speakers` via `voice_profiles:` keyword
4. **Specs**: Unit specs for matching, E2E spec for enrollment + identification roundtrip

Zero new gem dependencies. Server uses the already-loaded ECAPA-TDNN model.
