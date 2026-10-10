# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Social
        class QueueMeta < Component
          DAY = 86_400
          ENGAGEMENT = [
            [".likes", "fa-regular fa-heart", :like_count],
            [".reposts", "fa-solid fa-retweet", :repost_count],
            [".replies", "fa-regular fa-comment", :reply_count],
          ].freeze
          HOUR = 3600
          POSTED = Blog::Types::SocialPostStatus["posted"]

          prop :social_post, Blog::Types::Instance(ROM::Struct)
          prop :accounts, Blog::Types::Hash, default: -> { Blog::Constants::EMPTY_HASH }
          prop :now, Blog::Types::Time
          prop :suggestions, Blog::Types::Integer, default: 0

          def view_template
            p(class: "sq-meta") do
              @social_post.targets.each { network(it) }
              time_stamp
              engagement if posted?
              suggestion_count
            end
          end

          private

          def account(delivery) = @accounts.fetch(delivery.connection_id) { label(delivery.network) }

          def engagement
            ENGAGEMENT.each do |key, icon, column|
              total = @social_post.deliveries.sum { it.public_send(column) }

              span(class: "sq-metric", title: t(key), data: { social_engagement: column }, aria: { label: t(key) }) do
                IconLabel(icon:) { total.to_s }
              end
            end
          end

          def failing?(delivery) = delivery.failed || written?(delivery.error)

          def label(network) = t(Structs::Network::LABELS.fetch(network))

          def network(name)
            delivered = @social_post.deliveries.select { it.network == name }
            failing = delivered.any? { failing?(it) }
            return NetworkLabel(network: name, text: label(name), failing:) unless posted? && delivered.any?

            delivered.each do |delivery|
              text = delivered.one? ? label(name) : account(delivery)
              NetworkLabel(network: name, text:, failing: failing?(delivery), url: delivery.remote_url)
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
