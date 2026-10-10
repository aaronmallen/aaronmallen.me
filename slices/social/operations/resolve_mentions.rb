# frozen_string_literal: true

module Social
  module Operations
    class ResolveMentions
      BLUESKY = Blog::Types::NetworkName["bluesky"]
      MASTODON = Blog::Types::NetworkName["mastodon"]
      TOKEN = /@\{([^{}\p{White_Space}]+)\}/

      include Deps[person_queries: "repos.person_queries"]

      def call(texts, network)
        people = stored(texts)

        Array(texts).map { expand(people, it, network) }
      end

      def handles(people)
        Blog::Types::NetworkName.values.to_h do |network|
          [network, people.to_h { [it.key, label(it, network).first] }]
        end
      end

      def unknown(texts)
        people = stored(texts)

        keys(texts).reject { people.key?(it) }
      end

      private

      def add(expansion, shown, did = nil)
        expansion.mentions << mention(expansion.text.bytesize, shown, did) if did
        expansion.text << shown
      end

      def expand(people, text, network)
        pieces = text.to_s.split(TOKEN, -1).each_with_index.map do |piece, index|
          index.odd? ? shown(people, piece, network) : [piece]
        end

        pieces.each_with_object(Structs::Expansion.new(mentions: [], text: +"")) { |piece, found| add(found, *piece) }
      end

      def handle(person, network)
        case network
          when BLUESKY then person.bluesky_handle && ["@#{person.bluesky_handle}", person.bluesky_did]
          when MASTODON then person.mastodon_handle && [person.mastodon_handle]
        end
      end

      def keys(texts) = Array(texts).flat_map { it.to_s.scan(TOKEN).flatten }.uniq

      def label(person, network) = handle(person, network) || [person.name]

      def mention(start, shown, did) = Structs::Mention.new(byte_end: start + shown.bytesize, byte_start: start, did:)

      def shown(people, key, network)
        person = people[key]

        person ? label(person, network) : [key]
      end

      def stored(texts)
        keys = keys(texts)

        (keys.empty? ? [] : person_queries.by_keys(keys)).to_h { [it.key, it] }
      end
    end
  end
end
