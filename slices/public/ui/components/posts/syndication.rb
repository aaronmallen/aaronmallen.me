# frozen_string_literal: true

module Public
  module UI
    module Components
      module Posts
        class Syndication < Component
          NETWORKS = {
            Blog::Types::NetworkName["bluesky"] => %w[fa-bluesky .networks.bluesky].freeze,
            Blog::Types::NetworkName["mastodon"] => %w[fa-mastodon .networks.mastodon].freeze,
          }.freeze

          prop :urls, Blog::Types::Hash.map(Blog::Types::String, Blog::Types::String)

          def view_template
            return if @urls.empty?

            section(class: "post-syndication") do
              h2(class: "kicker") { t(".heading") }
              ul(class: "links") { @urls.each { |network, url| li { link(network, url) } } }
            end
          end

          private

          def link(network, url)
            icon, label_key = NETWORKS[network]

            a(class: "u-syndication", href: url) do
              IconLabel(icon: ["fa-brands", icon]) { t(label_key) }
            end
          end
        end
      end
    end
  end
end
