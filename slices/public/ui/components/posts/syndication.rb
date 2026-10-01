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

            div(class: "post-syndication") do
              span { t(".heading") }
              @urls.each { |network, url| link(network, url) }
            end
          end

          private

          def link(network, url)
            icon, label_key = NETWORKS[network]

            a(class: "post-syndication-link u-syndication", href: url) do
              i(class: ["fa-brands", icon], aria: { hidden: "true" })
              span { t(label_key) }
            end
          end
        end
      end
    end
  end
end
