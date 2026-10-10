# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class PublishedCard < Component
          POST = Blog::Types::ActivityKind["post"]
          POSTED = Blog::Types::SocialQueue["posted"]

          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :social_posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :days, Blog::Types::Array.of(Blog::Types::Date)

          def view_template
            Card(title: dotted(t(".title"), Blog::Helpers::Figures.count(count)), id: "review-published") do
              next Empty { t(".empty") } if count.zero?

              Capped(items: groups) { |name, records, href| group(name, records, href) }
            end
          end

          private

          def count = @posts.size + @social_posts.size

          def group(name, records, href)
            Group(name:, href:, items: records.reverse, days: @days, dated: :occurred_on) do |record|
              Line(href: href(record), text: record.name, day: record.occurred_on)
            end
          end

          def groups
            networks = Grouping.by(@social_posts) { it.targets.to_a.uniq }.map do |network, records|
              [t(Structs::Network::LABELS.fetch(network)), records, path(:admin_social, filter: POSTED)]
            end
            @posts.empty? ? networks : [[t(".posts"), @posts, path(:admin_posts)], *networks]
          end

          def href(record)
            return path(:admin_social, filter: POSTED) unless record.type == POST

            path(:admin_edit_post, id: record.source_id)
          end
        end
      end
    end
  end
end
