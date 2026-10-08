# frozen_string_literal: true

module Admin
  module UI
    module Components
      module RecordLinks
        class KindHeading < Component
          prop :kind, Blog::Types::RecordKind

          def view_template
            h3(class: "record-link-kind") do
              Icon(["fa-solid", Section::ICONS.fetch(@kind)])
              plain t(Section.kind_name_key(@kind))
            end
          end
        end
      end
    end
  end
end
