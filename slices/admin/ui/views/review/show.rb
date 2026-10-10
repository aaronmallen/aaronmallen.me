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
          prop :credits, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :choices, Blog::Types::Hash
          prop :group, Blog::Types::ReviewGroup, default: TAG

          def view_template
            PageHead(title: t(".heading"), sub:) do
              PeriodPager(
                period: @review.period, on: @on, from: @review.from, to: @review.to, today: @today,
                keep: { **ContributorFilter.query(@credits), **grouped },
              )
            end

            div(class: "g-main") do
              div(class: "cols") { cards }
              NoteCard(**note_card)
            end
          end

          private

          def cards
            DoneCard(**done_card)
            CarriedCard(carried: @review.carried)
            DecisionsCard(decisions: @review.decisions)
            JournalCard(journal: @review.journal, days:)
            PublishedCard(posts: @review.posts, social_posts: @review.social_posts, days:)
            ReposCard(commits: @review.commits)
            WorkedCard(worked: @review.worked)
          end

          def commit_count = @review.commits.values.sum { it[:commits] }

          def days = @days ||= (@review.from..[@review.to, @today].min).to_a

          def done_card
            {
              done: @review.done, credits: @credits, choices: @choices, keep: { **place, **grouped }, group: @group,
              from: @review.from, to: @review.to, days:,
            }
          end

          def done_count = @review.done.values.sum(&:size)

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

          def place
            { period: (@review.period if @review.period == MONTH), day: (@on.iso8601 unless @on == @today) }.compact
          end

          def span
            return l(@review.from, format: :month) if @review.period == MONTH

            t(".week", from: l(@review.from, format: :short), to: l(@review.to, format: :medium))
          end

          def sub
            t(
              ".summary",
              span:, done: done_count, carried: @review.carried.size, commits: t(".commits", count: commit_count),
              worked: Blog::Helpers::Figures.hours(@review.worked_seconds),
            )
          end
        end
      end
    end
  end
end
