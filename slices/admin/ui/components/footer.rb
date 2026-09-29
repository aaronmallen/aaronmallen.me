# frozen_string_literal: true

module Admin
  module UI
    module Components
      class Footer < Component
        def view_template
          footer(class: "adm-footer") do
            p(class: "adm-footer-version") { t(".version", version: Blog::Version::CURRENT) }
          end
        end
      end
    end
  end
end
