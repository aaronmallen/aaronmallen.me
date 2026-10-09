# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class QueueItem < Component
          DAY = 86_400
          ENGAGEMENT = [
            [".likes", "fa-regular fa-heart", :like_count],
            [".reposts", "fa-solid fa-retweet", :repost_count],
            [".replies", "fa-regular fa-comment", :reply_count],
          ].freeze
          HOUR = 3600
          NETWORK_ICONS = {
            Blog::Types::NetworkName["bluesky"] => "fa-brands fa-bluesky",
            Blog::Types::NetworkName["mastodon"] => "fa-brands fa-mastodon",
          }.freeze
          POSTED = Blog::Types::SocialPostStatus["posted"]

          prop :social_post, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :now, Blog::Types::Time
          prop :suggestions, Blog::Types::Integer, default: 0

          def view_template
            article(class: "sq-item", data: { social_item: @social_post.id, key_row: true }) do
              div(class: "sq-body") do
                div(class: "sq-text") { @social_post.parts.each { |part| p(class: "sq-part") { part.body } } }
                failures
                p(class: "sq-meta") { meta }
              end
              actions
            end
          end

          private

          def actions
            return if posted? || claimed?

            div(class: "sq-actions") do
              edit_link
              remove_form
            end
          end

          def claimed? = @social_post.deliveries.any?

          def edit_link
            Button(
              href: edit_path, small: true, title: t(".edit"), aria: { label: t(".edit") },
              icon: "fa-regular fa-pen-to-square", data: { social_edit: "", key_open: true },
            )
          end

          def edit_path = path(:admin_social, filter: @filter, edit: @social_post.id)

          def engagement
            ENGAGEMENT.each do |key, icon, column|
              total = @social_post.deliveries.sum { it.public_send(column) }

              span(class: "sq-metric", title: t(key), data: { social_engagement: column }, aria: { label: t(key) }) do
                IconLabel(icon:) { total.to_s }
              end
            end
          end

          def failing?(delivery) = delivery.failed || written?(delivery.error)

          def failure_text(delivery)
            error = delivery.error.to_s.strip
            detail = delivery.failed ? error : t(".retry_queued", error:)

            t(".failure", network: label(delivery.network), detail:)
          end

          def failures
            @social_post.deliveries.each do |delivery|
              next unless written?(delivery.error)

              p(class: "sq-fail") { failure_text(delivery) }
            end
          end

          def label(network) = t(Structs::Network::LABELS.fetch(network))

          def meta
            @social_post.targets.each { network(it) }
            time_stamp
            engagement if posted?
            suggestion_count
          end

          def network(name)
            failing = @social_post.deliveries.any? { it.network == name && failing?(it) }

            span(class: ["sq-network", ("bad" if failing)]) do
              IconLabel(icon: NETWORK_ICONS.fetch(name)) do
                failing ? t(".failed", network: label(name)) : label(name)
              end
            end
          end

          def posted? = @social_post.status == POSTED

          def relative(seconds)
            case seconds
              when ...Blog::Helpers::Figures::MINUTE then t(".in_a_moment")
              when ...HOUR then t(".in_minutes", count: seconds / Blog::Helpers::Figures::MINUTE)
              when ...DAY then t(".in_hours", count: seconds / HOUR)
              else t(".in_days", count: seconds / DAY)
            end
          end

          def remove_form
            Form(action: path(:admin_delete_social_post, id: @social_post.id)) do
              input(type: "hidden", name: "filter", value: @filter)
              Button(
                type: "submit", variant: :warn, small: true, title: t(".remove"), aria: { label: t(".remove") },
                icon: "fa-regular fa-trash-can", data: { social_remove_item: "" },
              )
            end
          end

          def suggestion_count
            return if posted? || @suggestions.zero?

            span(class: "sq-suggestions") do
              IconLabel(icon: "fa-solid fa-robot") { t(".suggestions", count: @suggestions) }
            end
          end

          def time_stamp
            at = @social_post.posted_at || @social_post.created_at
            seconds = (at - @now).to_i

            time(class: "sq-time", datetime: Blog::TimeZone.local(at).iso8601) do
              seconds.positive? ? relative(seconds) : l(Blog::TimeZone.today(at), format: :short)
            end
          end
        end
      end
    end
  end
end
