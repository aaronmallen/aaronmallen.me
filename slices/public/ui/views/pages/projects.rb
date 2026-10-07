# frozen_string_literal: true

module Public
  module UI
    module Views
      module Pages
        class Projects < View
          prop :past_projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            content_for(:title, t(".title"))
            content_for(:image, card_image)

            section(class: "projects") do
              span(class: "kicker") { t(".kicker") }
              h1(class: "page-title") { t(".heading") }
              p(class: "lede") { t(".lede") }
              ProjectGrid(projects: @projects) unless @projects.empty?
              past
            end
          end

          private

          def card_image = @projects.map(&:og_image_url).find { !it.to_s.empty? }

          def past
            return if @past_projects.empty?

            h2(class: "past-title") { t(".past") }
            ProjectGrid(projects: @past_projects)
          end
        end
      end
    end
  end
end
