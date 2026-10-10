# frozen_string_literal: true

module Social
  module Operations
    class UpdateWebmentionSettings < Blog::Operation
      include Deps[webmention_mutations: "repos.webmention_mutations", webmention_queries: "repos.webmention_queries"]

      def call(**attrs)
        step changed(attrs)

        webmention_mutations.update_settings(**attrs)
        webmention_queries.settings
      end

      private

      def changed(attrs)
        stored = webmention_queries.settings.to_h.slice(*attrs.keys)

        stored == attrs ? Failure(:unchanged) : Success(attrs)
      end
    end
  end
end
