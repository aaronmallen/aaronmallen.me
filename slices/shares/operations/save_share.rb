# frozen_string_literal: true

module Shares
  module Operations
    class SaveShare < Blog::Operation
      include Deps[
        "operations.change_code", "operations.rename_share_file", "operations.set_share_alt_text",
        share_queries: "repos.share_queries",
      ]

      def call(id, params)
        transaction do
          step change_code.call(step(find(id)), params)
          step set_share_alt_text.call(id, params) if params.key?(:alt_text)
          step rename_share_file.call(id, params) if params.key?(:filename)
          share_queries.find(id)
        end
      end

      private

      def find(id) = found(share_queries.find(id))
    end
  end
end
