# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class QueueItem < Component
          DAY = 86_400
          ENGAGEMENT = [
            [".likes", "fa-solid fa-heart", :like_count],
            [".reposts", "fa-solid fa-retweet", :repost_count],
            [".replies", "fa-solid fa-reply", :reply_count],
          ].freeze
          HOUR = 3600
          MINUTE = 60
          NETWORK_COLORS = {
            Blog::Types::NetworkName["bluesky"] => :blue,
            Blog::Types::NetworkName["mastodon"] => :violet,
          }.freeze
          POSTED = Blog::Types::SocialPostStatus["posted"]
          WRITING = /\S/

          prop :social_post, Blog::Types::Instance(ROM::Struct)
          prop :filter, Blog::Types::String
          prop :now, Blog::Types::Time
          prop :suggestions, Blog::Types::Integer, default: 0

          def view_template
            article(class: "sq-item", data: { social_item: @social_post.id, key_row: true }) do
              div(class: "sq-text") { @social_post.parts.each { |part| p(class: "sq-part") { part.body } } }
              failures
              div(class: "sq-foot") do
                div(class: "sq-meta") { meta }
                div(class: "sq-side") { side }
              end
            end
          end

          private

          def claimed? = @social_post.deliveries.any?

          def deliveries = @deliveries ||= @social_post.deliveries.to_h { [it.network, it] }

          def edit_link
            a(class: "btn sm", href: edit_path, data: { social_edit: "", key_open: true }) { t(".edit") }
          end

          def edit_path = path(:admin_social, filter: @filter, edit: @social_post.id)

          def engagement
            ENGAGEMENT.each do |key, icon, column|
              total = deliveries.each_value.sum { it.public_send(column) }

              span(class: "sq-metric", data: { social_engagement: column }, aria: { label: t(key) }) do
                IconLabel(icon:) { total.to_s }
              end
            end
          end

          def failing?(delivery) = !delivery.nil? && (delivery.failed || delivery.error.to_s.match?(WRITING))

          def failure_text(delivery)
            error = delivery.error.to_s.strip
            detail = delivery.failed ? error : t(".retry_queued", error:)

            t(".failure", network: label(delivery.network), detail:)
          end

          def failures
            @social_post.deliveries.each do |delivery|
              next unless delivery.error.to_s.match?(WRITING)

              p(class: "sq-fail") { failure_text(delivery) }
            end
          end

          def label(network) = t(Structs::Network::LABELS.fetch(network))

          def meta
            @social_post.targets.each { pill(it) }
            suggestions_pill
            time_stamp
          end

          def pill(network)
            return Pill(color: :pink) { t(".failed", network: label(network)) } if failing?(deliveries[network])

            Pill(color: NETWORK_COLORS.fetch(network)) { label(network) }
          end

          def posted? = @social_post.status == POSTED

          def relative(seconds)
            case seconds
            when ...MINUTE then t(".in_a_moment")
            when ...HOUR then t(".in_minutes", count: seconds / MINUTE)
            when ...DAY then t(".in_hours", count: seconds / HOUR)
            else t(".in_days", count: seconds / DAY)
            end
          end

          def remove_form
            Form(action: path(:admin_delete_social_post, id: @social_post.id)) do
              input(type: "hidden", name: "filter", value: @filter)
              Button(type: "submit", variant: :warn, small: true, data: { social_remove_item: "" }) { t(".remove") }
            end
          end

          def side
            return engagement if posted?
            return if claimed?

            edit_link
            remove_form
          end

          def suggestions_pill
            return if posted? || @suggestions.zero?

            Pill(color: :orange) { t(".suggestions", count: @suggestions) }
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
