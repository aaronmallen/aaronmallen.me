# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class SourceLink < Component
          ISSUE_PATH = "/issues/"
          ISSUE_SEPARATOR = "#"

          prop :source, Blog::Types::Instance(ROM::Struct).optional

          def view_template
            return if @source.nil?

            a(class: "task-source", href: @source.url, target: "_blank", rel: "noopener noreferrer") do
              i(class: "fa-brands fa-github", aria: { hidden: "true" })
              span { name }
            end
          end

          private

          def name = URI(@source.url).path.delete_prefix("/").sub(ISSUE_PATH, ISSUE_SEPARATOR)
        end
      end
    end
  end
end
