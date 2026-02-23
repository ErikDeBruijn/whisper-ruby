require "whisper"

RSpec.describe Whisper::Diarization do
  describe ".merge" do
    let(:transcription_chunks) do
      [
        { start: 0.0, end: 30.0, text: "Eerste stuk tekst." },
        { start: 30.0, end: 60.0, text: "Tweede stuk tekst." },
        { start: 60.0, end: 90.0, text: "Derde stuk tekst." }
      ]
    end

    let(:diarization_segments) do
      [
        { start: 0.0, end: 25.0, speaker: "SPEAKER_00" },
        { start: 25.0, end: 65.0, speaker: "SPEAKER_01" },
        { start: 65.0, end: 90.0, speaker: "SPEAKER_00" }
      ]
    end

    it "assigns speakers to chunks based on overlap" do
      merged = described_class.merge(transcription_chunks, diarization_segments)

      expect(merged[0][:speaker]).to eq("SPEAKER_00") # 0-30: 25s overlap with 00, 5s with 01
      expect(merged[1][:speaker]).to eq("SPEAKER_01") # 30-60: 30s overlap with 01
      expect(merged[2][:speaker]).to eq("SPEAKER_00") # 60-90: 25s overlap with 00, 5s with 01
    end

    it "handles empty diarization segments" do
      merged = described_class.merge(transcription_chunks, [])
      expect(merged).to eq([])
    end
  end

  describe ".apply_speaker_names" do
    it "replaces speaker IDs with names" do
      segments = [
        { start: 0.0, end: 10.0, speaker: "SPEAKER_00", text: "Hallo." },
        { start: 10.0, end: 20.0, speaker: "SPEAKER_01", text: "Hi." }
      ]

      named = described_class.apply_speaker_names(segments, {
        "SPEAKER_00" => "Erik",
        "SPEAKER_01" => "Steinar"
      })

      expect(named[0][:speaker]).to eq("Erik")
      expect(named[1][:speaker]).to eq("Steinar")
    end

    it "keeps original label for unknown speakers" do
      segments = [{ start: 0.0, end: 10.0, speaker: "SPEAKER_02", text: "Wie ben ik?" }]
      named = described_class.apply_speaker_names(segments, { "SPEAKER_00" => "Erik" })

      expect(named[0][:speaker]).to eq("SPEAKER_02")
    end
  end
end
