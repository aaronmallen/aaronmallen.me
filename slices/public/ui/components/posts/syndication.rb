# frozen_string_literal: true

module Public
  module UI
    module Components
      module Posts
        class Syndication < Component
          LABELS = {
            Blog::Types::NetworkName["bluesky"] => ".networks.bluesky",
            Blog::Types::NetworkName["mastodon"] => ".networks.mastodon",
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
            a(class: "u-syndication", href: url) do
              IconLabel(icon: Blog::Constants::NETWORK_ICONS[network]) { t(LABELS[network]) }
            end
          end
        end
      end
    end
  end
end
