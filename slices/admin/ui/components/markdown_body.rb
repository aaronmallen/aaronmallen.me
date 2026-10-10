# frozen_string_literal: true

module Admin
  module UI
    module Components
      class MarkdownBody < Component
        prop :source, Blog::Types::String
        prop :markdown, Blog::Types::Interface(:to_html)
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          div(**mix({ class: "post-body" }, @attributes)) { raw(safe(@markdown.to_html(@source).strip)) }
        end
      end
    end
  end
end
