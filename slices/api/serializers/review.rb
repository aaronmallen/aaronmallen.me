# frozen_string_literal: true

module API
  module Serializers
    class Review < Serializer
      OUTCOMES = %w[resolved dropped].map { Blog::Types::DecisionEventKind[it] }.freeze
      NOTE = "the note kept on the period, or null when it has none"
      CARRIED_TASK = Schema.object(
        { id: Schema::INTEGER, title: Schema::STRING, carried_count: Schema::INTEGER, sprint_on: Schema::DAY },
      ).freeze
      CREDITS = "who did the work; the owner when none is set"
      DONE_TASK = Schema.object(
        {
          id: Schema::INTEGER,
          title: Schema::STRING,
          worked_seconds: Schema::INTEGER,
          contributors: Schema.list(Task::CONTRIBUTOR).merge(description: CREDITS),
        },
      ).freeze
      RECORD = Schema.object({ id: Schema::INTEGER, date: Schema::DAY, name: Schema::STRING }).freeze

      SCHEMA = Schema.object(
        {
          period: { type: "string", enum: Blog::Types::ReviewPeriod.values },
          from: Schema::DAY,
          to: Schema::DAY,
          totals: Schema.object(
            {
              done: Schema::INTEGER,
              carried: Schema::INTEGER,
              worked_seconds: Schema::INTEGER,
              commits: Schema::INTEGER,
            },
          ),
          done: Schema.list(
            Schema.object(
              {
                date: Schema::DAY,
                tasks: Schema.list(DONE_TASK),
              },
            ),
          ),
          carried: Schema.list(CARRIED_TASK),
          posts: Schema.list(RECORD),
          social_posts: Schema.list(RECORD),
          journal: Schema.object({ entries: Schema.list(RECORD), words: Schema::INTEGER, streak: Schema::INTEGER }),
          commits: Schema.list(
            Schema.object(
              {
                repo: Schema::STRING,
                commits: Schema::INTEGER,
                additions: Schema::INTEGER,
                deletions: Schema::INTEGER,
              },
            ),
          ),
          decisions: Schema.list(
            Schema.object(
              {
                id: Schema::INTEGER,
                title: Schema::STRING,
                outcome: { type: "string", enum: OUTCOMES },
                chosen: Schema.nullable(Schema::STRING),
                reason: Schema::STRING,
                date: Schema::DAY,
              },
            ),
          ),
          worked: Schema.list(Schema.object({ date: Schema::DAY, seconds: Schema::INTEGER })),
          note: { oneOf: [ReviewNote.reference, { type: "null" }], description: NOTE },
        },
      ).freeze

      schema_attributes

      def carried(review)
        review.carried.map do |task|
          { id: task.task_id, title: task.title, carried_count: task.carried_count, sprint_on: day(task.sprint_date) }
        end
      end

      def commits(review)
        review.commits.map { |repo, totals| { repo:, **totals.slice(:commits, :additions, :deletions) } }
      end

      def decisions(review)
        review.decisions.map do |decision|
          {
            id: decision.decision_id,
            title: decision.title,
            outcome: decision.outcome,
            chosen: decision.chosen,
            reason: decision.reason,
            date: day(decision.closed_on),
          }
        end
      end

      def done(review)
        review.done.map do |date, tasks|
          { date: day(date), tasks: tasks.map { done_task(it) } }
        end
      end

      def from(review) = day(review.from)

      def journal(review)
        found = review.journal

        { entries: records(found.entries), words: found.words, streak: found.streak }
      end

      def note(_review) = params[:note]&.then { ReviewNote.new(it).serializable_hash }

      def posts(review) = records(review.posts)

      def social_posts(review) = records(review.social_posts)

      def to(review) = day(review.to)

      def totals(review)
        {
          done: review.done.values.sum(&:size),
          carried: review.carried.size,
          worked_seconds: review.worked_seconds,
          commits: review.commits.values.sum { it[:commits] },
        }
      end

      def worked(review) = review.worked.map { |date, seconds| { date: day(date), seconds: } }

      private

      def done_task(task)
        {
          id: task.task_id,
          title: task.title,
          worked_seconds: task.worked_seconds,
          contributors: Task.credits(task.contributors),
        }
      end

      def records(found) = found.map { { id: it.source_id, date: day(it.occurred_on), name: it.name } }
    end
  end
end
