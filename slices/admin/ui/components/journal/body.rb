# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class Body < Component
          prop :body, Blog::Types::String
          prop :attributes, Blog::Types::Hash, :**

          def view_template
            div(**mix({ class: "journal-entry-body post-body" }, @attributes)) do
              raw(safe(::Posts::Markdown.to_html(@body).strip))
            end
          end
        end
      end
    end
  end
end
