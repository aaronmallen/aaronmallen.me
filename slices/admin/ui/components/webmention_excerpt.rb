# frozen_string_literal: true

module Admin
  module UI
    module Components
      class WebmentionExcerpt < Component
        prop :mention, Blog::Types::Instance(ROM::Struct)
        prop :attributes, Blog::Types::Hash, :**

        def view_template
          p(**mix({ class: ["wm-excerpt", ("quiet" if text.empty?)] }, @attributes)) do
            text.empty? ? t(".no_content") : text
          end
        end

        private

        def text = @mention.excerpt.to_s.strip
      end
    end
  end
end
