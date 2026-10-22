# frozen_string_literal: true

module Admin
  module Operations
    class BuildPersonEditor
      FIELDS = %i[name key mastodon_handle bluesky_handle].freeze

      def call(person: nil, params: nil, errors: Blog::Constants::EMPTY_HASH)
        values = params ? from_params(params) : from_person(person)

        { person:, values:, errors: }
      end

      private

      def from_params(params)
        email = Blog::Types::Fields[Array(params[:emails]).first][:value]

        FIELDS.to_h { [it, Blog::Types::Text[params[it]]] }.merge(email: Blog::Types::Text[email])
      end

      def from_person(person) = FIELDS.to_h { [it, person&.public_send(it).to_s] }.merge(email: "")
    end
  end
end
