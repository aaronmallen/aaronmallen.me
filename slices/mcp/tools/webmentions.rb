# frozen_string_literal: true

module MCP
  module Tools
    module Webmentions
      VISITOR_FIELDS = %w[author_name author_url excerpt source_url].freeze

      module_function

      def marked(mention) = mention.merge(VISITOR_FIELDS.to_h { [it, Untrusted.call(mention.fetch(it))] })
    end
  end
end
