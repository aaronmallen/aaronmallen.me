# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Tasks
        class SourceLink < Component
          ICONS = {
            Blog::Types::TaskSourceProvider["github"] => Blog::Constants::GITHUB_ICON,
            Blog::Types::TaskSourceProvider["linear"] => "linear-mark",
          }.freeze

          prop :source, Blog::Types::Instance(ROM::Struct).optional

          def view_template
            return if @source.nil?

            a(class: "task-source", href: @source.url, **OUTBOUND) do
              IconLabel(icon: ICONS.fetch(@source.provider)) { ::Tasks::Structs::SourceReference.for(@source).name }
            end
          end
        end
      end
    end
  end
end
