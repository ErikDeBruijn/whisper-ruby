require "whisper"
require "tempfile"

RSpec.describe Whisper::VoiceProfileLibrary do
  let(:tmpfile) { Tempfile.new(["profiles", ".json"]) }
  let(:library) { described_class.new(tmpfile.path) }

  after { tmpfile.close! }

  describe "#add and #find" do
    it "stores and retrieves a profile" do
      library.add("Erik", [0.1, 0.2, 0.3])

      profile = library.find("Erik")
      expect(profile["embeddings"]).to eq([[0.1, 0.2, 0.3]])
    end

    it "appends multiple embeddings for the same person" do
      library.add("Erik", [0.1, 0.2, 0.3])
      library.add("Erik", [0.4, 0.5, 0.6])

      profile = library.find("Erik")
      expect(profile["embeddings"].size).to eq(2)
    end

    it "stores notes" do
      library.add("Erik", [0.1, 0.2, 0.3], notes: "From Envitron meeting")

      profile = library.find("Erik")
      expect(profile["notes"]).to eq("From Envitron meeting")
    end
  end

  describe "#remove" do
    it "deletes a profile" do
      library.add("Erik", [0.1, 0.2, 0.3])
      library.remove("Erik")

      expect(library.find("Erik")).to be_nil
    end
  end

  describe "#all" do
    it "lists all profiles" do
      library.add("Erik", [0.1, 0.2, 0.3])
      library.add("Steinar", [0.4, 0.5, 0.6])

      expect(library.all.keys).to contain_exactly("Erik", "Steinar")
    end
  end

  describe "persistence" do
    it "saves and reloads from JSON" do
      library.add("Erik", [0.1, 0.2, 0.3])

      reloaded = described_class.new(tmpfile.path)
      expect(reloaded.find("Erik")["embeddings"]).to eq([[0.1, 0.2, 0.3]])
    end
  end

  describe "#resolve" do
    let(:erik_embedding) { [1.0, 0.0, 0.0] }
    let(:steinar_embedding) { [0.0, 1.0, 0.0] }

    before do
      library.add("Erik", erik_embedding)
      library.add("Steinar", steinar_embedding)
    end

    it "matches speakers to profiles by cosine similarity" do
      speaker_embeddings = {
        "SPEAKER_00" => [0.95, 0.05, 0.0],
        "SPEAKER_01" => [0.05, 0.95, 0.0]
      }

      result = library.resolve(speaker_embeddings, threshold: 0.7)

      expect(result["SPEAKER_00"]).to eq("Erik")
      expect(result["SPEAKER_01"]).to eq("Steinar")
    end

    it "does not match below threshold" do
      speaker_embeddings = {
        "SPEAKER_00" => [0.0, 0.0, 1.0]
      }

      result = library.resolve(speaker_embeddings, threshold: 0.7)

      expect(result).to be_empty
    end

    it "assigns each profile at most once (greedy)" do
      speaker_embeddings = {
        "SPEAKER_00" => [0.9, 0.1, 0.0],
        "SPEAKER_01" => [0.8, 0.2, 0.0]
      }

      result = library.resolve(speaker_embeddings, threshold: 0.5)

      expect(result["SPEAKER_00"]).to eq("Erik")
      expect(result.values.count("Erik")).to eq(1)
    end

    it "leaves unmatched speakers unmapped" do
      speaker_embeddings = {
        "SPEAKER_00" => [0.95, 0.05, 0.0],
        "SPEAKER_01" => [0.05, 0.95, 0.0],
        "SPEAKER_02" => [0.0, 0.0, 1.0]
      }

      result = library.resolve(speaker_embeddings, threshold: 0.7)

      expect(result).not_to have_key("SPEAKER_02")
    end
  end
end

RSpec.describe Whisper::VoiceProfile do
  describe ".learn_voiceprint" do
    it "calls /embed and stores the mean embedding" do
      tmpfile = Tempfile.new(["profiles", ".json"])
      library = Whisper::VoiceProfileLibrary.new(tmpfile.path)

      allow(described_class).to receive(:fetch_embedding)
        .with("/path/to/audio.wav")
        .and_return([0.1, 0.2, 0.3])

      described_class.learn_voiceprint("Erik", "/path/to/audio.wav", library: library)

      expect(library.find("Erik")["embeddings"]).to eq([[0.1, 0.2, 0.3]])
    ensure
      tmpfile.close!
    end
  end

  describe ".identify" do
    it "identifies a known speaker" do
      tmpfile = Tempfile.new(["profiles", ".json"])
      library = Whisper::VoiceProfileLibrary.new(tmpfile.path)
      library.add("Erik", [1.0, 0.0, 0.0])

      result = described_class.identify([0.95, 0.05, 0.0], library: library)

      expect(result[:name]).to eq("Erik")
      expect(result[:score]).to be > 0.9
    ensure
      tmpfile.close!
    end

    it "returns nil for unknown speaker" do
      tmpfile = Tempfile.new(["profiles", ".json"])
      library = Whisper::VoiceProfileLibrary.new(tmpfile.path)
      library.add("Erik", [1.0, 0.0, 0.0])

      result = described_class.identify([0.0, 0.0, 1.0], library: library)

      expect(result).to be_nil
    ensure
      tmpfile.close!
    end
  end
end
