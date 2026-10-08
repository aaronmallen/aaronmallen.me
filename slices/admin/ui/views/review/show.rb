# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Review
        class Show < View
          include Components::Review

          MONTH = Blog::Types::ReviewPeriod["month"]

          prop :review, Blog::Types::Instance(::Activity::Structs::Review)
          prop :note, Blog::Types::Instance(ROM::Struct).optional
          prop :on, Blog::Types::Date
          prop :today, Blog::Types::Date
          prop :note_body, Blog::Types::String.optional
          prop :errors, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :credits, Blog::Types::Hash, default: Blog::Constants::EMPTY_HASH
          prop :choices, Blog::Types::Hash

          def view_template
            PageHead(title: t(".heading"), sub:) do
              PeriodPager(
                period: @review.period, on: @on, from: @review.from, to: @review.to, today: @today,
                keep: ContributorFilter.query(@credits),
              )
            end

            Grid(columns: 4) { stats }

            Grid(columns: 2) do
              SideStack { task_cards }
              SideStack { record_cards }
            end

            NoteCard(**note_card)
          end

          private

          def commit_count = @review.commits.values.sum { it[:commits] }

          def done_count = @review.done.values.sum(&:size)

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

          def record_cards
            PublishedCard(posts: @review.posts, social_posts: @review.social_posts)
            JournalCard(journal: @review.journal)
            ReposCard(commits: @review.commits)
            DecisionsCard(decisions: @review.decisions)
          end

          def stats
            Stat(key: t(".done"), value: done_count)
            Stat(key: t(".carried"), value: @review.carried.size)
            Stat(key: t(".worked"), value: Blog::Helpers::Figures.hours(@review.worked_seconds))
            Stat(key: t(".commits"), value: commit_count)
          end

          def sub
            return l(@review.from, format: :month) if @review.period == MONTH

            t(".week", from: l(@review.from, format: :short), to: l(@review.to, format: :medium))
          end

          def task_cards
            DoneCard(done: @review.done, credits: @credits, choices: @choices, keep: place)
            CarriedCard(carried: @review.carried)
            WorkedCard(worked: @review.worked)
          end
        end
      end
    end
  end
end
