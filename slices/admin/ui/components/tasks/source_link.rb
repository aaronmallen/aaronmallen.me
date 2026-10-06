# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class SourceLink < Component
          ICONS = {
            Blog::Types::TaskSourceProvider["github"] => "fa-brands fa-github",
            Blog::Types::TaskSourceProvider["linear"] => "fa-solid fa-circle-half-stroke",
          }.freeze

          prop :source, Blog::Types::Instance(ROM::Struct).optional

          def view_template
            return if @source.nil?

            a(class: "task-source", href: @source.url, target: "_blank", rel: "noopener noreferrer") do
              IconLabel(icon: ICONS.fetch(@source.provider)) { ::Tasks::SourceReference.for(@source).name }
            end
          end
        end
      end
    end
  end
end
