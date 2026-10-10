# frozen_string_literal: true

module Admin
  module UI
    module Components
      class QuietCard < Component
        DRAFT = Blog::Types::PostStatus["draft"]
        JOURNAL_KEY = "w"
        QUEUED = Blog::Types::SocialQueue["queued"]

        prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
        prop :posts, Blog::Types::Hash
        prop :social, Blog::Types::Hash
        prop :queue, Blog::Types::Hash
        prop :visitors, Blog::Types::Integer
        prop :clients, Blog::Types::Integer

        def view_template
          Card do
            journal_line
            ships_next
            TodayLine(label: t(".drafts"), href: path(:admin_posts, status: DRAFT)) do
              t(".draft_count", count: @posts[:drafts].size)
            end
            site_lines
          end
        end

        private

        def journal_line
          href = path(:admin_journal, write: Blog::Constants::CHECKED)

          TodayLine(label: t(".journal"), href:, data: { dialog_open: Journal::WriteDialog::ID }) do
            plain t(".journal_count", count: @entries.size)
            whitespace
            kbd(class: "kbd", aria: { hidden: "true" }) { JOURNAL_KEY }
          end
        end

        def next_up
          [
            *@posts[:scheduled].first(1).map { [it.published_at, path(:admin_edit_post, id: it.id)] },
            *@social[:scheduled].first(1).map { [it.posted_at, path(:admin_social, filter: QUEUED)] },
          ].min_by(&:first)
        end

        def ships_next
          at, href = next_up
          return TodayLine(label: t(".ships_next"), href: path(:admin_calendar)) { t(".nothing_scheduled") } unless at

          TodayLine(label: t(".ships_next"), href:) do
            Moment(at:)
            plain "#{DOT}#{t('.queued', count: @queue[:count])}"
          end
        end

        def site_lines
          TodayLine(label: t(".visitors"), href: path(:admin_analytics)) { t(".visitor_count", count: @visitors) }
          TodayLine(label: t(".clients"), href: path(:admin_clients)) { t(".client_count", count: @clients) }
        end
      end
    end
  end
end
