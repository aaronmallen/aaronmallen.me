# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class Group < Component
          PREVIEW = 2
          SPARK_FLOOR = 18

          prop :name, Blog::Types::String
          prop :href, Blog::Types::String
          prop :items, Blog::Types::Array
          prop :days, Blog::Types::Array.of(Blog::Types::Date)
          prop :dated, Blog::Types::Symbol
          prop :label, Blog::Types::String.optional, default: nil

          def view_template(&)
            div(class: "review-group") do
              head
              div(class: "review-top") do
                @items.first(PREVIEW).each(&)
                more = @items.size - PREVIEW
                span(class: "meta") { more_text(t(".more", count: more)) } if more.positive?
              end
            end
          end

          private

          def bar(count)
            return i(class: "zero") if count.zero?

            i(style: "height: #{[SPARK_FLOOR, Blog::Helpers::Figures.share(count, counts.values.max)].max}%")
          end

          def counts = @counts ||= @items.map { it.public_send(@dated) }.tally

          def head
            a(class: "review-group-head", href: @href, aria: { label: t(".open", count: @items.size, name: @name) }) do
              span(class: "review-group-name") { @name }
              spark unless @days.empty?
              span(class: "review-group-count") { Blog::Helpers::Figures.count(@items.size) }
            end
          end

          def more_text(more) = [more, @label].compact.join(" ")

          def spark
            span(class: "review-spark", aria: { hidden: true }) { @days.each { bar(counts.fetch(it, 0)) } }
          end
        end
      end
    end
  end
end
