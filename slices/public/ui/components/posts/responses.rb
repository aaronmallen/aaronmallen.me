# frozen_string_literal: true

module Public
  module UI
    module Components
      module Posts
        class Responses < Component
          COUNT_KEYS = {
            Blog::Types::WebmentionType["like"] => ".likes",
            Blog::Types::WebmentionType["repost"] => ".reposts",
          }.freeze
          REL = "nofollow ugc noopener"
          SEPARATOR = " · "

          prop :responses, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :counts, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::Integer)

          def view_template
            return if @responses.empty? && @counts.empty?

            section(class: "post-responses") do
              h2(class: "post-responses-title") { t(".heading") }
              count_row
              response_list
            end
          end

          private

          def count_row
            labels = COUNT_KEYS.filter_map { |type, key| t(key, count: @counts[type]) if @counts[type] }
            return if labels.empty?

            p(class: "post-response-counts") { labels.join(SEPARATOR) }
          end

          def excerpt(mention)
            text = mention.excerpt.to_s.strip
            p(class: "post-response-text p-content") { text } unless text.empty?
          end

          def response(mention)
            li(class: "post-response h-cite u-comment") do
              p(class: "post-response-head") do
                a(class: "post-response-author u-url", href: mention.source_url, rel: REL) do
                  span(class: "p-author h-card") { span(class: "p-name") { mention.author_label } }
                end
                Date(time: mention.received_at)
              end
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
