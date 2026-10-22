# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Who < Component
          prop :person, Blog::Types::Instance(ROM::Struct).optional
          prop :sender, Blog::Types::String.optional
          prop :email, Blog::Types::String.optional
          prop :form, Blog::Types::Bool
          prop :spam, Blog::Types::Bool

          def view_template
            div(class: "mail-who") { @person ? known : stranger }
          end

          private

          def add_path = path(:admin_new_person, name: (@sender unless @sender == @email), email: @email)

          def known
            name("fa-solid fa-user-group") { plain @person.name }
            Button(variant: :gh, small: true, href: path(:admin_edit_person, id: @person.id)) { t(".open_person") }
          end

          def name(icon, dim: false)
            p(class: ["mail-who-name", ("mail-dim" if dim)]) do
              Icon(icon)
              yield
            end
          end

          def stranger
            name("fa-regular fa-user", dim: true) { plain t(@form ? ".stranger_form" : ".stranger", name: @sender) }
            return if @spam

            Button(variant: :gh, small: true, icon: :add, href: add_path) { t(".add_person") }
          end
        end
      end
    end
  end
end
