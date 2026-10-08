# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class JournalCard < Component
          TEXT_LIMIT = 80

          prop :journal, Blog::Types::Instance(::Activity::Structs::ReviewJournal)

          def view_template
            Card(title: t(".title"), id: "review-journal") do
              p(class: "review-note") { t(".totals", **totals) }
              next Empty { t(".empty") } if @journal.entries.empty?

              @journal.entries.each { entry(it) }
            end
          end

          private

          def entry(record)
            day = record.occurred_on
            title = Blog::Helpers::Truncation.cut(record.name, keep: TEXT_LIMIT)

            ListItem(title:, href: href(day), sub: l(day, format: :weekday))
          end

          def href(day) = "#{path(:admin_journal, to: day.iso8601)}##{Journal::Day.anchor(day)}"

          def totals
            {
              entries: t(".entries", count: @journal.entries.size),
              words: t(".words", count: @journal.words, words: Blog::Helpers::Figures.count(@journal.words)),
              streak: t(".streak", count: @journal.streak),
            }
          end
        end
      end
    end
  end
end
