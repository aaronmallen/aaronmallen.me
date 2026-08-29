# frozen_string_literal: true

module Public
  module UI
    module Views
      module Pages
        class Projects < View
          def initialize(projects:)
            super()
            @projects = projects
          end

          def view_template
            content_for(:title, t(".title"))
            content_for(:image, card_image)

            section(class: "projects") do
              span(class: "kicker") { t(".kicker") }
              h1(class: "page-title") { t(".heading") }
              p(class: "lede") { t(".lede") }
              ProjectGrid(projects: @projects) unless @projects.empty?
            end
          end

          private

          def card_image = @projects.map(&:og_image_url).find { !it.to_s.empty? }
        end
      end
    end
  end
end
