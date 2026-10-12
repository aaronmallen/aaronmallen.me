# frozen_string_literal: true

module API
  module Serializers
    class MailMessage < Serializer
      SCHEMA = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          reply_to: Helpers::Schema::STRING,
          subject: Helpers::Schema::STRING,
          body: Helpers::Schema::STRING,
          received_at: Helpers::Schema::STAMP,
        },
      ).freeze

      schema_attributes
      stamps :received_at
    end
  end
end
