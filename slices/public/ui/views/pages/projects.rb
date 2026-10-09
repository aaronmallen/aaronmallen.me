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
              page_head
              ProjectGrid(projects: @projects) unless @projects.empty?
              past
            end
          end

          private

          def card_image = @projects.map(&:og_image_url).find { !it.to_s.empty? }

          def page_head
            header(class: "hd") do
              span(class: "kicker") { t(".kicker") }
              h1 { t(".heading") }
              p(class: "ld") { t(".lede") }
            end
          end

          def past
            return if @past_projects.empty?

            h2(class: "kicker kt") { t(".past") }
            ProjectGrid(projects: @past_projects, past: true)
          end
        end
      end
    end
  end
end
