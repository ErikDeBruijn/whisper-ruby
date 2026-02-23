require "whisper"

RSpec.describe Whisper do
  after { described_class.reset_client! }

  describe ".configure" do
    it "sets base_url" do
      described_class.configure { |c| c.base_url = "http://custom:9090/inference" }
      expect(described_class.base_url).to eq("http://custom:9090/inference")
    ensure
      described_class.base_url = nil
    end

    it "sets chunk_duration" do
      described_class.configure { |c| c.chunk_duration = 90 }
      expect(described_class.chunk_duration).to eq(90)
    ensure
      described_class.chunk_duration = nil
    end
  end

  describe ".base_url" do
    it "falls back to ENV" do
      described_class.base_url = nil
      allow(ENV).to receive(:fetch).with("WHISPER_URL", anything).and_return("http://from-env:8081/inference")
      expect(described_class.base_url).to eq("http://from-env:8081/inference")
    end
  end

  describe ".client" do
    it "returns a Client instance" do
      expect(described_class.client).to be_a(Whisper::Client)
    end

    it "memoizes the client" do
      expect(described_class.client).to be(described_class.client)
    end
  end

  describe ".reset_client!" do
    it "clears the memoized client" do
      first = described_class.client
      described_class.reset_client!
      expect(described_class.client).not_to be(first)
    end
  end
end
