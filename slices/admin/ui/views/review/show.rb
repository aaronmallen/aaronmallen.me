# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Review
        class Show < View
          include Components::Review

          MONTH = Blog::Types::ReviewPeriod["month"]
          TAG = Blog::Types::ReviewGroup["tag"]

          prop :review, Blog::Types::Instance(::Activity::Structs::Review)
          prop :note, Blog::Types::Instance(ROM::Struct).optional
          prop :on, Blog::Types::Date
          prop :today, Blog::Types::Date
          prop :note_body, Blog::Types::String.optional
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :by, Blog::Types::String.optional, default: nil
          prop :agents, Blog::Types::Array.of(Blog::Types::String), default: Blog::Constants::EMPTY_ARRAY
          prop :group, Blog::Types::ReviewGroup, default: TAG

          def view_template
            PageHead(title: t(".heading"), sub:) { actions }
            Heat(
              days: @review.days, period: @review.period, focus: @review.focus, today: @today,
              keep: { **place, **grouped, **picked },
            )
            div(class: "g-main") do
              div(class: "cols") { cards }
              NoteCard(**note_card)
            end
          end

          private

          def actions
            PeriodPager(
              period: @review.period, on: @on, from: @review.from, to: @review.to, today: @today,
              keep: { **grouped, **picked },
            )
            DoneBy(by: @by, agents: @agents, keep: { **place, **focused, **grouped })
          end

          def cards
            DoneCard(**done_card)
            CarriedCard(carried: @review.carried)
            DecisionsCard(decisions: @review.decisions)
            records
            ReposCard(commits: @review.commits)
            WorkedCard(worked: @review.worked, focused: day?)
          end

          def commit_count = @review.commits.values.sum { it[:commits] }

          def day? = !@review.focus.nil?

          def days
            return Blog::Constants::EMPTY_ARRAY if day?

            @days ||= (@review.from..[@review.to, @today].min).to_a
          end

          def done_card
            {
              done: @review.done, keep: { **place, **focused, **picked }, group: @group,
              from: @review.focus || @review.from, to: @review.focus || @review.to, days:, focused: day?,
            }
          end

          def done_count = @review.done.values.sum(&:size)

          def focused = @review.focus ? { focus: @review.focus.iso8601 } : Blog::Constants::EMPTY_HASH

          def grouped = @group == TAG ? Blog::Constants::EMPTY_HASH : { group: @group }

          def note_card
            {
              body: @note_body || @note&.body || Blog::Constants::EMPTY_STRING,
              errors: @errors,
              period: @review.period,
              saved: !@note.nil?,
              to: @review.to,
            }
          end

          def picked = @by ? { by: @by } : Blog::Constants::EMPTY_HASH

          def place
            { period: (@review.period if @review.period == MONTH), day: (@on.iso8601 unless @on == @today) }.compact
          end

          def records
            JournalCard(journal: @review.journal, days:, focused: day?)
            PublishedCard(posts: @review.posts, social_posts: @review.social_posts, days:)
            EarlierCard(earlier: @review.earlier)
          end

          def span
            return l(@review.focus, format: :full) if @review.focus
            return l(@review.from, format: :month) if @review.period == MONTH

            t(".week", from: l(@review.from, format: :short), to: l(@review.to, format: :medium))
          end

          def sub
            t(
              ".summary",
              span:, done: done_count, commits: t(".commits", count: commit_count),
              worked: Blog::Helpers::Figures.hours(@review.worked_seconds),
            )
          end
        end
      end
    end
  end
end
