# frozen_string_literal: true

module Admin
  module Operations
    class BuildPersonEditor
      FIELDS = %i[name key mastodon_handle bluesky_handle].freeze

      include Deps[networks: "social.networks.all"]

      def call(person: nil, params: nil, errors: Blog::Constants::EMPTY_HASH)
        values = params ? FIELDS.to_h { [it, Blog::Types::Text[params[it]]] } : from_person(person)

        { person:, values:, errors:, searchable: }
      end

      private

      def from_person(person) = FIELDS.to_h { [it, person&.public_send(it).to_s] }

      def searchable = Blog::Types::NetworkName.values.select { networks.fetch(it).configured? }
    end
  end
end
