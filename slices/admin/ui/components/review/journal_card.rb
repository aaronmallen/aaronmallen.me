# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Review
        class JournalCard < Component
          prop :journal, Blog::Types::Instance(::Activity::Structs::ReviewJournal)
          prop :days, Blog::Types::Array.of(Blog::Types::Date)

          def view_template
            Card(title: t(".title"), id: "review-journal") do
              totals
              tagged if groups.any? { |key, _| key }
              next Empty { t(".empty") } if entries.empty?

              div(class: "review-foot") { a(class: "today-link", href: path(:admin_journal)) { t(".open") } }
            end
          end

          private

          def entries = @journal.entries

          def entry(record)
            day = record.occurred_on

            href = "#{path(:admin_journal, to: day.iso8601)}##{Journal::Day.anchor(day)}"

            Line(href:, text: record.name, day:)
          end

          def group(key, members)
            Group(
              name: key ? "##{key}" : t(".untagged"), href: path(:admin_journal), items: members, days: @days,
              dated: :occurred_on, label: t(".entries_more"),
            ) { entry(it) }
          end

          def groups = @groups ||= Grouping.by(entries, &:tags)

          def tagged
            div(class: "review-groups") { Capped(items: groups) { |key, members| group(key, members) } }
          end

          def totals
            p(class: "today-stat review-stat") do
              plain Blog::Helpers::Figures.count(entries.size)
              whitespace
              small { t(".totals", **words) }
            end
          end

          def words
            written = entries.map(&:occurred_on).uniq.size

            {
              entries: t(".entries", count: entries.size),
              words: t(".words", count: @journal.words, words: Blog::Helpers::Figures.count(@journal.words)),
              days: t(".days", count: written),
            }
          end
        end
      end
    end
  end
end
