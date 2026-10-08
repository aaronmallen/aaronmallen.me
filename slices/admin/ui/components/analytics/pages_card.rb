# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Analytics
        class PagesCard < Component
          prop :paths, Blog::Types::Array.of(Blog::Types::Hash)

          def view_template
            Card(title: t(".title")) do
              next Empty { t(".empty") } if @paths.empty?

              div(class: "tbl-scroll") do
                table(class: "tbl") do
                  thead { headings }
                  tbody { @paths.each { row(it) } }
                end
              end
            end
          end

          private

          def headings
            tr do
              th(class: "tbl-h") { t(".page") }
              th(class: "tbl-h") { t(".views") }
              th(class: "tbl-h") { t(".time") }
              th(class: "tbl-h end") { t(".bounce") }
            end
          end

          def page(entry)
            div(class: "tbl-page") do
              page_title(entry)
              span(class: "tbl-path") { entry[:path] }
            end
          end

          def page_title(entry)
            text = entry[:title] || entry[:path]
            id = entry[:post_id]
            return span(class: "tbl-title") { text } unless id

            a(class: "tbl-title", href: path(:admin_post_analytics, id:)) { text }
          end

          def row(entry)
            tr do
              td(class: "tbl-c") { page(entry) }
              td(class: "tbl-c num") { Blog::Helpers::Figures.count(entry[:views]) }
              td(class: "tbl-c num") { Blog::Helpers::Figures.duration(Blog::Helpers::Figures.average(entry[:read_seconds], entry[:views])) }
              td(class: "tbl-c num end") { t(".percent", value: Blog::Helpers::Figures.share(entry[:bounces], entry[:visitors])) }
            end
          end
        end
      end
    end
  end
end
