# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Sessions
        class New < View
          PROVIDERS = {
            "github" => ["fa-brands fa-github", ".github"],
            "google" => ["fa-brands fa-google", ".google"],
          }.freeze

          def view_template
            PageHead(title: t(".heading"), sub: t(".sub")) do
              PROVIDERS.each do |provider, (icon, label)|
                Form(action: path(:admin_start_sign_in, provider:)) do
                  Button(type: "submit", variant: :pri, icon:) { t(label) }
                end
              end
            end
          end
        end
      end
    end
  end
end
