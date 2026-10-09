# frozen_string_literal: true

module Public
  module Actions
    module Robots
      class Show < Action
        PRIVATE_PATHS = %w[/admin /api /mcp /oauth /pulse /webmention].freeze

        config.formats.clear.accept :txt
        answer_any_accept :txt

        share_with_caches

        def handle(_request, response)
          rules = PRIVATE_PATHS.map { "Disallow: #{it}" }
          response.body = ["User-agent: *", *rules, "Allow: /", "", "Sitemap: #{routes.url(:sitemap)}", ""].join("\n")
        end
      end
    end
  end
end
