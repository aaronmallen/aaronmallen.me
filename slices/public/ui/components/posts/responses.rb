# frozen_string_literal: true

module Public
  module UI
    module Components
      module Posts
        class Responses < Component
          COUNTS = {
            Blog::Types::WebmentionType["like"] => %w[.likes fa-heart],
            Blog::Types::WebmentionType["repost"] => %w[.reposts fa-retweet],
          }.freeze
          REL = "nofollow ugc noopener"

          prop :responses, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)

          def view_template
            return if @responses.empty? && @counts.empty?

            section(class: "post-responses") do
              h2(class: "kicker") { t(".heading") }
              count_row
              response_list
            end
          end

          private

          def count_row
            counts = COUNTS.select { |type, _| @counts[type] }
            return if counts.empty?

            p(class: "post-response-counts") do
              counts.each do |type, (key, icon)|
                span { IconLabel(icon: ["fa-solid", icon]) { t(key, count: @counts[type]) } }
              end
            end
          end

          def excerpt(mention)
            text = mention.excerpt.to_s.strip
            p(class: "post-response-text p-content") { text } unless text.empty?
          end

          def handle(mention)
            domain = mention.author_domain
            span(class: "post-response-handle") { domain } if domain && domain != mention.author_label
          end

          def head(mention)
            div(class: "post-response-head") do
              a(class: "post-response-author u-url", href: mention.source_url, rel: REL) do
                span(class: "p-author h-card") { span(class: "p-name") { mention.author_label } }
              end
              handle(mention)
              Date(time: mention.received_at)
            end
          end

          def response(mention)
            li(class: "post-response h-cite u-comment") do
              span(class: "post-response-avatar", aria: { hidden: "true" }) { mention.author_label[0].upcase }
              head(mention)
              excerpt(mention)
            end
          end

          def response_list
            return if @responses.empty?

            ol(class: "post-response-list") { @responses.each { response(it) } }
          end
        end
      end
    end
  end
end
