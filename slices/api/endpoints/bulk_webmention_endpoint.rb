# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    class BulkWebmentionEndpoint < BulkEndpoint
      KEY = :webmentions
      NOUN = "webmention"
      REPLY = Helpers::Schema.object({ webmentions: Helpers::Schema.list(Serializers::Webmention.reference) }).freeze
      SCHEMA = Webmentions::BULK

      include Deps[act_on: "social.operations.act_on_webmentions"]

      private

      def answered(mentions) = serialized(Serializers::Webmention, mentions)
    end
  end
end
