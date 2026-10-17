# frozen_string_literal: true

module API
  module Serializers
    class Client < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          name: { type: "string", description: "the name the client registered, else its redirect host" },
          scopes: {
            type: "array",
            items: { type: "string", enum: Blog::Types::OAuthScope.values },
            description: "the scopes its live tokens hold",
          },
          created_at: Helpers::Schema::STAMP,
          last_used_at: Helpers::Schema.nullable(Helpers::Schema::STAMP.merge(description: "null if never used")),
        },
      ).freeze

      schema_attributes
      stamps :created_at, :last_used_at

      def name(client)
        untrusted(client.display_name)
      end

      def scopes(client) = params.fetch(:scopes).fetch(client.id)
    end
  end
end
