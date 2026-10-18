# frozen_string_literal: true

module Admin
  module UI
    module Components
      class QuietCard < Component
        DRAFT = Blog::Types::PostStatus["draft"]
        JOURNAL_KEY = "w"
        QUEUED = Blog::Types::SocialQueue["queued"]

        prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :last_night, Blog::Types::Instance(ROM::Struct).optional, default: nil
        prop :publishing, Blog::Types::Hash
        prop :visitors, Blog::Types::Integer
        prop :clients, Blog::Types::Integer

        def view_template
          Card do
            journal_line
            ships_next
            last_night
            TodayLine(label: t(".drafts"), href: path(:admin_posts, status: DRAFT)) do
              t(".draft_count", count: @publishing[:drafts])
            end
            site_lines
          end
        end

        private

        def journal_line
          href = path(:admin_journal, write: Blog::Constants::CHECKED)

          TodayLine(label: t(".journal"), href:, **Dialog.opens(Journal::WriteDialog::ID)) do
            plain t(".journal_count", count: @entries.size)
            whitespace
            kbd(class: "kbd", aria: { hidden: "true" }) { JOURNAL_KEY }
          end
        end

        def last_night
          return unless HealthFigures.slept?(@last_night)

          TodayLine(label: t(".last_night"), href: path(:admin_activity)) { HealthFigures(day: @last_night) }
        end

        def next_up
          post, social_at = @publishing.values_at(:next_post, :next_social_at)

          [
            post && [post.published_at, path(:admin_edit_post, id: post.id)],
            social_at && [social_at, path(:admin_social, filter: QUEUED)],
          ].compact.min_by(&:first)
        end

        def ships_next
          at, href = next_up
          return TodayLine(label: t(".ships_next"), href: path(:admin_calendar)) { t(".nothing_scheduled") } unless at

          TodayLine(label: t(".ships_next"), href:) do
            Moment(at:)
            plain "#{DOT}#{t('.queued', count: @publishing[:queued])}"
          end
        end

        def site_lines
          TodayLine(label: t(".visitors"), href: path(:admin_analytics)) { t(".visitor_count", count: @visitors) }
          clients = Helpers::ServiceTab.clients(routes)
          TodayLine(label: t(".clients"), href: clients) { t(".client_count", count: @clients) }
        end
      end
    end
  end
end
