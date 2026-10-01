# frozen_string_literal: true

module Social
  class Mentions
    Expansion = Data.define(:mentions, :text)
    Mention = Data.define(:byte_end, :byte_start, :did)

    BLUESKY = Blog::Types::NetworkName["bluesky"]
    MASTODON = Blog::Types::NetworkName["mastodon"]
    TOKEN = /@\{([^{}[:space:]]+)\}/

    def self.keys(texts) = Array(texts).flat_map { it.to_s.scan(TOKEN).flatten }.uniq

    def initialize(people)
      @people = people.to_h { [it.key, it] }
    end

    def expand(text, network)
      pieces = text.to_s.split(TOKEN, -1).each_with_index.map do |piece, index|
        index.odd? ? shown(piece, network) : [piece]
      end

      pieces.each_with_object(Expansion.new(mentions: [], text: +"")) { |piece, expansion| add(expansion, *piece) }
    end

    def unknown(texts) = self.class.keys(texts).reject { @people.key?(it) }

    private

    def add(expansion, shown, did = nil)
      expansion.mentions << mention(expansion.text.bytesize, shown, did) if did
      expansion.text << shown
    end

    def handle(person, network)
      case network
      when BLUESKY then person.bluesky_handle && ["@#{person.bluesky_handle}", person.bluesky_did]
      when MASTODON then person.mastodon_handle && [person.mastodon_handle]
      end
    end

    def mention(start, shown, did) = Mention.new(byte_end: start + shown.bytesize, byte_start: start, did:)

    def shown(key, network)
      person = @people[key]
      return [key] unless person

      handle(person, network) || [person.name]
    end
  end
end
