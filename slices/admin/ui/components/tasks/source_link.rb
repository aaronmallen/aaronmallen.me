# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class SourceLink < Component
          GITHUB = Blog::Types::TaskSourceProvider["github"]
          LINEAR = Blog::Types::TaskSourceProvider["linear"]

          ICONS = { GITHUB => "fa-brands fa-github", LINEAR => "fa-solid fa-circle-half-stroke" }.freeze
          ISSUE_PATH = "/issues/"
          ISSUE_SEPARATOR = "#"
          LINEAR_KEY = %r{/issue/([^/]+)}

          prop :source, Blog::Types::Instance(ROM::Struct).optional

          def view_template
            return if @source.nil?

            a(class: "task-source", href: @source.url, target: "_blank", rel: "noopener noreferrer") do
              i(class: ICONS.fetch(@source.provider), aria: { hidden: "true" })
              span { name }
            end
          end

          private

          def github_name = path.delete_prefix("/").sub(ISSUE_PATH, ISSUE_SEPARATOR)

          def linear_key = path[LINEAR_KEY, 1]

          def name = @source.provider == LINEAR ? linear_key : github_name

          def path = URI(@source.url).path
        end
      end
    end
  end
end
