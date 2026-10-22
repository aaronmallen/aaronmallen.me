# frozen_string_literal: true

module API
  module Serializers
    class ShortLink < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          code: { type: "string", description: "the link's short code on the share host" },
          url: { type: "string", description: "the short link, which sends a reader on to the destination" },
          destination: { type: "string", description: "the address the short link sends a reader to" },
          title: Helpers::Schema.nullable(
            { type: "string", description: "the destination's title; null until the site reads it from the page" },
          ),
          click_count: Helpers::Schema::INTEGER,
          last_clicked_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          retargeted_at: Helpers::Schema.nullable(Helpers::Schema::STAMP),
          created_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :last_clicked_at, :retargeted_at, :created_at
      untrusted :title

      def url(link) = params.fetch(:settings).share_url(link.code)
    end
  end
end
