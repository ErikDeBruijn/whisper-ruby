require "spec_helper"
require "tempfile"
require_relative "../support/tts_audio"

RSpec.describe "Diarization E2E", :e2e do
  let(:client) { Whisper::Client.new }

  describe "two-speaker conversation" do
    let(:speaker_a_text) { "Good morning. I would like to discuss the project timeline and deliverables for next quarter." }
    let(:speaker_b_text) { "Sure, let me pull up the schedule. We have three major milestones planned before the end of March." }

    let(:audio_path) do
      TTSAudio.generate_multispeaker([
        { text: speaker_a_text, voice: "Daniel" },
        { text: speaker_b_text, voice: "Samantha" }
      ], silence_gap: 2.0)
    end

    it "detects two speakers" do
      result = client.transcribe_with_speakers(audio_path, language: "en", min_speakers: 2)

      expect(result[:speakers]).to eq(2)
    end

    it "assigns different speakers to different segments" do
      result = client.transcribe_with_speakers(audio_path, language: "en", min_speakers: 2)

      non_empty = result[:segments].reject { |s| s[:text]&.strip&.empty? }
      speakers = non_empty.map { |s| s[:speaker] }.uniq

      expect(speakers.size).to eq(2),
        "Expected 2 distinct speakers, got: #{speakers.inspect}\nSegments: #{non_empty.inspect}"
    end

    it "preserves content from both speakers" do
      result = client.transcribe_with_speakers(audio_path, language: "en", min_speakers: 2)

      full_text = result[:segments].map { |s| s[:text] }.join(" ")

      sim_a = TTSAudio.text_similarity(speaker_a_text, full_text)
      sim_b = TTSAudio.text_similarity(speaker_b_text, full_text)

      expect(sim_a).to be >= 0.5,
        "Speaker A content not found.\nExpected: #{speaker_a_text}\nFull: #{full_text}"
      expect(sim_b).to be >= 0.5,
        "Speaker B content not found.\nExpected: #{speaker_b_text}\nFull: #{full_text}"
    end

    it "applies speaker name mapping" do
      result = client.transcribe_with_speakers(
        audio_path,
        language: "en",
        min_speakers: 2,
        speaker_names: { "SPEAKER_00" => "Alice", "SPEAKER_01" => "Bob" }
      )

      speakers = result[:segments].map { |s| s[:speaker] }.uniq
      expect(speakers).to include("Alice").or include("Bob")
      expect(speakers).not_to include("SPEAKER_00")
      expect(speakers).not_to include("SPEAKER_01")
    end
  end

  describe "voice profile resolution" do
    let(:speaker_a_text) { "Hello, my name is Daniel and I work in engineering at a large technology company." }
    let(:speaker_b_text) { "Hi Daniel, I am Samantha and I handle marketing for our product division." }

    let(:audio_path) do
      TTSAudio.generate_multispeaker([
        { text: speaker_a_text, voice: "Daniel" },
        { text: speaker_b_text, voice: "Samantha" }
      ], silence_gap: 2.0)
    end

    let(:enroll_a_path) do
      TTSAudio.generate_segment(
        "This is a sample of my voice for enrollment purposes. I speak clearly and at a normal pace.",
        voice: "Daniel"
      )
    end

    let(:enroll_b_path) do
      TTSAudio.generate_segment(
        "This is a sample of my voice for enrollment purposes. I speak clearly and at a normal pace.",
        voice: "Samantha"
      )
    end

    let(:profiles) do
      tmpfile = Tempfile.new(["profiles", ".json"])
      lib = Whisper::VoiceProfileLibrary.new(tmpfile.path)
      Whisper::VoiceProfile.learn_voiceprint("PersonA", enroll_a_path, library: lib)
      Whisper::VoiceProfile.learn_voiceprint("PersonB", enroll_b_path, library: lib)
      lib
    end

    it "resolves speakers to enrolled profile names" do
      result = client.transcribe_with_speakers(
        audio_path,
        language: "en",
        min_speakers: 2,
        voice_profiles: profiles
      )

      speakers = result[:segments].map { |s| s[:speaker] }.uniq
      expect(speakers).to include("PersonA").or include("PersonB")
    end
  end

  describe "three-speaker conversation" do
    let(:audio_path) do
      TTSAudio.generate_multispeaker([
        { text: "Welcome everyone to today's meeting. Let's start with the agenda.", voice: "Daniel" },
        { text: "I have prepared the quarterly report. Revenue is up fifteen percent.", voice: "Samantha" },
        { text: "That is great news. We should celebrate this achievement with the whole team.", voice: "Karen" }
      ], silence_gap: 2.0)
    end

    it "detects three speakers" do
      result = client.transcribe_with_speakers(audio_path, language: "en", min_speakers: 3)

      expect(result[:speakers]).to eq(3)
    end
  end
end
