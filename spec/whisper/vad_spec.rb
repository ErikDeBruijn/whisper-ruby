require "whisper"

RSpec.describe Whisper::VAD do
  describe ".detect_silences" do
    it "parses ffmpeg silencedetect output" do
      ffmpeg_output = <<~OUTPUT
        [silencedetect @ 0x1234] silence_start: 3.749458
        [silencedetect @ 0x1234] silence_end: 5.060646 | silence_duration: 1.311187
        [silencedetect @ 0x1234] silence_start: 8.976083
        [silencedetect @ 0x1234] silence_end: 9.764792 | silence_duration: 0.788708
      OUTPUT

      allow(described_class).to receive(:`).and_return(ffmpeg_output)

      silences = described_class.detect_silences("/tmp/test.wav")

      expect(silences).to eq([
        { start: 3.749458, end: 5.060646, duration: 1.311187 },
        { start: 8.976083, end: 9.764792, duration: 0.788708 }
      ])
    end
  end

  describe ".compute_chunks" do
    let(:silences) do
      [
        { start: 55.0, end: 56.0, duration: 1.0 },
        { start: 115.0, end: 117.0, duration: 2.0 },
        { start: 125.0, end: 126.0, duration: 1.0 },
        { start: 240.0, end: 242.0, duration: 2.0 }
      ]
    end

    it "returns a single chunk for short audio" do
      chunks = described_class.compute_chunks(60.0, silences, 120)
      expect(chunks).to eq([[0.0, 60.0]])
    end

    it "splits at the longest silence near the target boundary" do
      chunks = described_class.compute_chunks(300.0, silences, 120)

      expect(chunks.first[0]).to eq(0.0)
      expect(chunks.first[1]).to eq(116.0) # midpoint of the 2s silence at 115-117
    end

    it "absorbs short trailing segments" do
      chunks = described_class.compute_chunks(145.0, silences, 120)

      expect(chunks.size).to eq(1)
      expect(chunks.last[1]).to eq(145.0)
    end
  end
end
