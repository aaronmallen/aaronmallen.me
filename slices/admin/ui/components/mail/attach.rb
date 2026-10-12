# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        class Attach < Component
          prop :scope, Blog::Types::String

          def view_template
            input(id:, class: "sr-only", type: "file", name: "mail[files][]", multiple: true, data: { mail_files: "" })
            label(class: "bt sm gh", for: id) do
              Icon("fa-solid fa-paperclip")
              plain t(".attach")
            end
            span(class: "mail-attach-names", data: { mail_file_names: "" })
          end

          private

          def id = "#{@scope}-files"
        end
      end
    end
  end
end
