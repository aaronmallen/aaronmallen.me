# frozen_string_literal: true

module Admin
  module UI
    module Components
      class GitHubRecord < Component
        EMPTY = "ui.components.github_record.empty"

        prop :body_html, Blog::Types::String.optional
        prop :label, Blog::Types::String
        prop :title, Blog::Types::String
        prop :records, Blog::Types::Hash
        prop :kind, Blog::Types::RecordKind
        prop :id, Blog::Types::Integer
        prop :find_path, Blog::Types::String

        def view_template(&)
          div(class: "g-main") do
            Card(label: @label, title: @title) do
              body
              div(class: "commit-stats", &)
            end
            aside { RecordLinks::Section(records: @records, kind: @kind, id: @id, find_path: @find_path) }
          end
        end

        private

        def body
          return Empty { t([EMPTY, @kind].join(".")) } unless @body_html

          div(class: "commit-body post-body") { raw(safe(@body_html)) }
        end
      end
    end
  end
end
