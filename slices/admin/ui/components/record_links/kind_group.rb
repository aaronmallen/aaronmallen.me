# frozen_string_literal: true

module Admin
  module UI
    module Components
      module RecordLinks
        class KindGroup < Component
          prop :kind, Blog::Types::RecordKind

          def view_template(&)
            div(class: "record-link-group") do
              h3(class: "record-link-kind") do
                Icon(["fa-solid", row.icon])
                plain t(row.label)
              end
              ul(class: "record-link-list", &)
            end
          end

          private

          def row = Blog::Helpers::RecordKinds.fetch(@kind)
        end
      end
    end
  end
end
