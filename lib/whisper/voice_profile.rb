require "json"
require "net/http"

module Whisper
  class VoiceProfileLibrary
    attr_reader :path

    def initialize(path = nil)
      @path = path || Whisper.profiles_path
      @profiles = load_profiles
    end

    def all
      @profiles.dup
    end

    def find(name)
      @profiles[name]
    end

    def add(name, embedding, notes: nil)
      @profiles[name] ||= { "embeddings" => [], "notes" => nil }
      @profiles[name]["embeddings"] << embedding
      @profiles[name]["notes"] = notes if notes
      save
    end

    def remove(name)
      @profiles.delete(name)
      save
    end

    def resolve(speaker_embeddings, threshold: nil)
      threshold ||= Whisper.profile_threshold
      return {} if @profiles.empty? || speaker_embeddings.empty?

      scores = []
      speaker_embeddings.each do |speaker_id, cluster_centroid|
        centroid = cluster_centroid.is_a?(Array) ? cluster_centroid : cluster_centroid.to_a
        @profiles.each do |name, profile|
          best_score = profile["embeddings"].map { |emb| cosine_similarity(centroid, emb) }.max
          scores << { speaker: speaker_id, name: name, score: best_score }
        end
      end

      greedy_match(scores, threshold)
    end

    def save
      File.write(@path, JSON.pretty_generate(@profiles))
    end

    private

    def load_profiles
      return {} unless File.exist?(@path)

      content = File.read(@path)
      return {} if content.strip.empty?

      JSON.parse(content)
    end

    def cosine_similarity(a, b)
      dot = 0.0
      norm_a = 0.0
      norm_b = 0.0
      a.each_with_index do |x, i|
        y = b[i]
        dot += x * y
        norm_a += x * x
        norm_b += y * y
      end
      return 0.0 if norm_a.zero? || norm_b.zero?

      dot / (Math.sqrt(norm_a) * Math.sqrt(norm_b))
    end

    def greedy_match(scores, threshold)
      sorted = scores.sort_by { |s| -s[:score] }
      assigned_speakers = {}
      assigned_profiles = {}

      sorted.each do |s|
        next if s[:score] < threshold
        next if assigned_speakers.key?(s[:speaker])
        next if assigned_profiles.key?(s[:name])

        assigned_speakers[s[:speaker]] = s[:name]
        assigned_profiles[s[:name]] = s[:speaker]
      end

      assigned_speakers
    end
  end

  module VoiceProfile
    class << self
      def library(path = nil)
        VoiceProfileLibrary.new(path)
      end

      def learn_voiceprint(name, audio_path, notes: nil, library: nil)
        lib = library || VoiceProfileLibrary.new
        embedding = fetch_embedding(audio_path)
        lib.add(name, embedding, notes: notes)
        lib
      end

      def all(library: nil)
        lib = library || VoiceProfileLibrary.new
        lib.all
      end

      def remove(name, library: nil)
        lib = library || VoiceProfileLibrary.new
        lib.remove(name)
        lib
      end

      def resolve(speaker_embeddings, threshold: nil, library: nil)
        lib = library || VoiceProfileLibrary.new
        lib.resolve(speaker_embeddings, threshold: threshold)
      end

      def identify(embedding, library: nil)
        lib = library || VoiceProfileLibrary.new
        best_name = nil
        best_score = -1.0
        threshold = Whisper.profile_threshold

        lib.all.each do |name, profile|
          profile["embeddings"].each do |stored|
            score = lib.send(:cosine_similarity, embedding, stored)
            if score > best_score
              best_score = score
              best_name = name
            end
          end
        end

        best_score >= threshold ? { name: best_name, score: best_score } : nil
      end

      def similarity(name, audio_path, library: nil)
        lib = library || VoiceProfileLibrary.new
        profile = lib.find(name)
        raise Error, "Profile '#{name}' not found" unless profile

        embedding = fetch_embedding(audio_path)
        profile["embeddings"].map do |stored|
          lib.send(:cosine_similarity, embedding, stored)
        end.max
      end

      private

      def fetch_embedding(audio_path)
        uri = URI(Whisper.embed_url)
        file = File.open(audio_path, "rb")

        form_data = [
          ["file", file, { filename: File.basename(audio_path), content_type: "audio/wav" }]
        ]

        request = Net::HTTP::Post.new(uri)
        request.set_form(form_data, "multipart/form-data")

        response = Net::HTTP.start(uri.hostname, uri.port, read_timeout: 600) do |http|
          http.request(request)
        end

        file.close

        raise Error, "Embed server returned HTTP #{response.code}" unless response.is_a?(Net::HTTPSuccess)

        data = JSON.parse(response.body)
        raise Error, "No embeddings returned for #{audio_path}" if data["mean"].empty?

        data["mean"]
      end
    end
  end
end
