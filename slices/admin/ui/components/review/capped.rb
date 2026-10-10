# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class Capped < Component
          CAP = 5

          prop :items, Blog::Types::Array
          prop :more, Blog::Types::String.optional, default: nil

          def view_template(&)
            @items.first(CAP).each(&)
            return if rest.empty?

            @more ? all_link : reveal(&)
          end

          private

          def all_link
            div(class: "review-foot") { a(class: "today-link", href: @more) { t(".all", count: @items.size) } }
          end

          def rest = @rest ||= @items.drop(CAP)

          def reveal(&)
            details(class: "review-more") do
              summary(class: "today-link") do
                span(class: "review-more-show") { t(".show", count: rest.size) }
                span(class: "review-more-hide") { t(".hide") }
              end
              rest.each(&)
            end
          end
        end
      end
    end
  end
end
