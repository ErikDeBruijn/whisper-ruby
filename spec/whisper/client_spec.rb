require "whisper"
require "webmock/rspec"

RSpec.describe Whisper::Client do
  subject(:client) { described_class.new(base_url: "http://whisper.test:8081/inference") }

  describe "#transcribe_short" do
    before do
      allow(client).to receive(:system).and_return(true)

      stub_request(:post, "http://whisper.test:8081/inference")
        .to_return(status: 200, body: { text: " Hallo wereld." }.to_json)
    end

    it "transcribes a short audio file" do
      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with("/tmp/test.wav.wav", "rb").and_return(StringIO.new("fake wav"))
      allow(File).to receive(:exist?).with("/tmp/test.wav.wav").and_return(true)
      allow(File).to receive(:delete).with("/tmp/test.wav.wav")

      result = client.transcribe_short("/tmp/test.wav")
      expect(result).to eq("Hallo wereld.")
    end
  end

  describe "error handling" do
    it "raises Whisper::Error on HTTP failure" do
      allow(client).to receive(:system).and_return(true)

      stub_request(:post, "http://whisper.test:8081/inference")
        .to_return(status: 500, body: "Internal Server Error")

      allow(File).to receive(:open).and_call_original
      allow(File).to receive(:open).with("/tmp/test.wav.wav", "rb").and_return(StringIO.new("fake wav"))
      allow(File).to receive(:exist?).with("/tmp/test.wav.wav").and_return(true)
      allow(File).to receive(:delete).with("/tmp/test.wav.wav")

      expect { client.transcribe_short("/tmp/test.wav") }.to raise_error(Whisper::Error, /HTTP 500/)
    end
  end

  describe "#clean_repetitions (via format_results)" do
    it "removes hallucination loops" do
      results = [
        {
          start: 0.0, end: 120.0,
          text: "Dit is een test. Dit is een test. Dit is een test. Dit is een test. Einde."
        }
      ]

      output = client.send(:format_results, results)
      expect(output.scan("Dit is een test.").size).to eq(2)
      expect(output).to include("Einde.")
    end
  end
end
