# frozen_string_literal: true

module API
  module Serializers
    class TrustedAuthor < Serializer
      SCHEMA = Helpers::Schema.object({ author_url: Helpers::Schema::STRING,
                                        created_at: Helpers::Schema::STAMP }).freeze

      schema_attributes
      stamps :created_at
      untrusted :author_url
    end
  end
end
