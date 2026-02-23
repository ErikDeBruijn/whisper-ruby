require "spec_helper"
require_relative "../support/tts_audio"

RSpec.describe "Transcription E2E", :e2e do
  let(:client) { Whisper::Client.new }

  describe "short transcription roundtrip" do
    it "transcribes a single TTS-generated English sentence" do
      text = "The weather is beautiful today and I am going for a walk in the park."
      audio_path = TTSAudio.generate_segment(text, voice: "Daniel")

      result = client.transcribe_short(audio_path, language: "en")

      similarity = TTSAudio.text_similarity(text, result)
      expect(similarity).to be >= 0.7,
        "Expected >=70% word match.\nOriginal: #{text}\nWhisper:  #{result}\nSimilarity: #{(similarity * 100).round(1)}%"
    end

    it "transcribes a Dutch sentence" do
      text = "Het weer is vandaag erg mooi en ik ga een wandeling maken in het bos."
      audio_path = TTSAudio.generate_segment(text, voice: "Ellen")

      result = client.transcribe_short(audio_path, language: "nl")

      similarity = TTSAudio.text_similarity(text, result)
      expect(similarity).to be >= 0.6,
        "Expected >=60% word match.\nOriginal: #{text}\nWhisper:  #{result}\nSimilarity: #{(similarity * 100).round(1)}%"
    end
  end

  describe "long transcription with VAD chunking" do
    it "transcribes multiple concatenated segments" do
      sentences = [
        "Artificial intelligence is transforming the way we work and live.",
        "Electric vehicles are becoming more affordable every year.",
        "The future of energy is renewable and decentralized."
      ]

      segments = sentences.map { |s| { text: s, voice: "Daniel" } }
      audio_path = TTSAudio.generate_multispeaker(segments, silence_gap: 1.5)

      result = client.transcribe(audio_path, language: "en")

      sentences.each do |sentence|
        similarity = TTSAudio.text_similarity(sentence, result)
        expect(similarity).to be >= 0.5,
          "Expected sentence to appear in transcription.\nSentence: #{sentence}\nFull result: #{result}"
      end
    end
  end
end
