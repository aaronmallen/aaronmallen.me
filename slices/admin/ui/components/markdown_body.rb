# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MarkdownBody < Component
        POSTS = Blog::Types::MarkdownRenderer["posts"]

        prop :source, Blog::Types::String
        prop :renderer, Blog::Types::MarkdownRenderer
        prop :attributes, Blog::Types::Hash, :**

        include Deps["settings"]

        def view_template
          div(**mix({ class: "post-body" }, @attributes)) { raw(safe(html.strip)) }
        end

        private

        def html
          return ::Markdown.to_html(@source) if @renderer == POSTS

          ::Markdown::Note.to_html(@source, origin: settings.site_origin)
        end
      end
    end
  end
end
