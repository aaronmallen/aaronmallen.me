# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Posts
        class LinksDrawer < Component
          FORM = "post-links-check"
          ID = "post-links"

          prop :links, Blog::Types::Array.of(Blog::Types::Hash)
          prop :published, Blog::Types::Bool
          prop :open, Blog::Types::Bool

          def self.failing(links) = links.select { it[:check]&.reason }.sort_by { -it[:check].failures }

          def view_template
            Dialog(**dialog_attributes) do |dialog|
              dialog.foot { foot }
              @links.empty? ? empty : listed
            end
          end

          private

          def check_all
            Button(small: true, type: "submit", form: FORM, icon: "fa-solid fa-rotate") { t(".check_all") }
          end

          def dialog_attributes
            {
              id: ID, title: t(".title"), class: "wide", hidden: false,
              data: { dialog: true, dialog_live: true, dialog_show: (true if @open) },
            }
          end

          def empty
            p(class: "post-links-sum") { b { t(".no_links") } }
            Empty { t(".empty") }
          end

          def failing = @failing ||= self.class.failing(@links)

          def fine = @links.select { it[:check] && !it[:check].reason }

          def fine_rows
            details(class: "post-links-fine", open: (true if failing.empty? && unchecked.empty?)) do
              summary(class: "post-links-fine-head") do
                Icon("fa-solid fa-chevron-right time-caret")
                plain t(".fine", count: fine.size)
              end
              fine.each { LinkCheckRow(**it, published: @published, quiet: true) }
            end
          end

          def foot
            check_all if @published && @links.any?
            Button(variant: :pri, small: true, data: { dialog_close: true }) { t(".done") }
          end

          def listed
            summary_line
            Hint { t(@published ? ".hint_live" : ".hint_draft") }
            (failing + unchecked).each { LinkCheckRow(**it, published: @published) }
            fine_rows if fine.any?
          end

          def summary_line
            p(class: "post-links-sum", role: "status") do
              b { t(".count", count: @links.size) }
              tally
            end
          end

          def tally
            return span { t(".all_fine") } if failing.empty? && unchecked.empty?

            span(class: "post-links-bad") { t(".failing", count: failing.size) } if failing.any?
            span { t(".unchecked", count: unchecked.size) } if unchecked.any?
          end

          def unchecked = @links.reject { it[:check] }
        end
      end
    end
  end
end
