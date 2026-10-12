# frozen_string_literal: true

module Mail
  module Operations
    class UpdateMailSettings < Blog::Operation
      include Deps[message_mutations: "repos.message_mutations", message_queries: "repos.message_queries"]

      def call(rules: {}, accounts: {})
        message_mutations.update_settings(rules, accounts)
        Success(message_queries.settings)
      end
    end
  end
end
