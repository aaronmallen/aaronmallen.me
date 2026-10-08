# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class PublishedCard < Component
          POST = Blog::Types::ActivityKind["post"]
          POSTED = Blog::Types::SocialQueue["posted"]
          TEXT_LIMIT = 80

          prop :posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :social_posts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Card(title: t(".title"), id: "review-published") do
              next Empty { t(".empty") } if @posts.empty? && @social_posts.empty?

              group(t(".posts"), @posts)
              group(t(".social_posts"), @social_posts)
            end
          end

          private

          def group(title, records)
            return if records.empty?

            section(class: "review-group") do
              h3(class: "review-group-title") { title }
              records.each { ListItem(**item(it)) }
            end
          end

          def href(record)
            record.type == POST ? path(:admin_edit_post, id: record.source_id) : path(:admin_social, filter: POSTED)
          end

          def item(record)
            {
              title: Blog::Helpers::Truncation.cut(record.name, keep: TEXT_LIMIT),
              href: href(record),
              sub: l(record.occurred_on, format: :weekday),
            }
          end
        end
      end
    end
  end
end
