# frozen_string_literal: true

module Public
  module UI
    module Components
      class SearchLimit < Component
        def view_template
          div(class: "sq-n wait", role: "status") do
            h2 { IconLabel(icon: "fa-solid fa-hourglass-half") { t(".heading") } }
            lede
            div(class: "acts") do
              a(href: path(:writing)) { IconLabel(icon: "fa-solid fa-list") { t(".writing") } }
              a(href: path(:projects)) { IconLabel(icon: "fa-solid fa-cube") { t(".projects") } }
            end
          end
        end

        private

        def lede
          p do
            plain t(".lede")
            b { t(".wait") }
            plain t(".kept")
          end
        end
      end
    end
  end
end
