# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Journal
        class WordCount < Component
          prop :count, Blog::Types::Integer

          def view_template
            span(class: "journal-words", data: { journal_words: "", one: t(".words.one"), other: t(".words.other") }) do
              t(".words", count: @count)
            end
          end
        end
      end
    end
  end
end
