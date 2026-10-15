# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Services
        class Head < Component
          prop :title, Blog::Types::String
          prop :definition, Blog::Types::Instance(::Services::Structs::Definition)

          def view_template
            div(class: "svc-head") do
              h2(class: "card-title") do
                Tile(definition: @definition)
                plain(@title)
              end
              Button(small: true, variant: :gh, icon: :close, href: path(:admin_services), label: t(".close"))
            end
          end
        end
      end
    end
  end
end
