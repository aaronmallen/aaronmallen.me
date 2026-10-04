# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Review
        class Show < View
          include Components::Review

          MONTH = Blog::Types::ReviewPeriod["month"]

          def initialize(review:, note:, on:, today:, note_body: nil, errors: Blog::Constants::EMPTY_HASH)
            super()
            @review = review
            @note = { body: note_body || note&.body || Blog::Constants::EMPTY_STRING, saved: !note.nil?, errors: }
            @on = on
            @today = today
          end

          def view_template
            PageHead(title: t(".heading"), sub:) do
              PeriodPager(period: @review.period, on: @on, from: @review.from, to: @review.to, today: @today)
            end

            Grid(columns: 4) { stats }

            Grid(columns: 2) do
              SideStack { task_cards }
              SideStack { record_cards }
            end

            NoteCard(**@note, period: @review.period, to: @review.to)
          end

          private

          def commit_count = @review.commits.values.sum { it[:commits] }

          def done_count = @review.done.values.sum(&:size)

          def record_cards
            PublishedCard(posts: @review.posts, social_posts: @review.social_posts)
            JournalCard(journal: @review.journal)
            ReposCard(commits: @review.commits)
          end

          def stats
            Stat(key: t(".done"), value: done_count)
            Stat(key: t(".carried"), value: @review.carried.size)
            Stat(key: t(".worked"), value: Blog::Figures.hours(@review.worked_seconds))
            Stat(key: t(".commits"), value: commit_count)
          end

          def sub
            return l(@review.from, format: :month) if @review.period == MONTH

            t(".week", from: l(@review.from, format: :short), to: l(@review.to, format: :medium))
          end

          def task_cards
            DoneCard(done: @review.done)
            CarriedCard(carried: @review.carried)
            WorkedCard(worked: @review.worked)
          end
        end
      end
    end
  end
end
