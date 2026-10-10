# frozen_string_literal: true

module API
  module Serializers
    class Review < Serializer
      REMEMBERED = %w[journal post].map { Blog::Types::ActivityKind[it] }.freeze
      OUTCOMES = %w[resolved dropped].map { Blog::Types::DecisionEventKind[it] }.freeze
      EARLIER = "the journal entries and posts from the same dates in earlier years, newest first"
      FOCUS = "the one day every section but carried covers, or null for the whole period"
      NOTE = "the note kept on the period, or null when it has none"
      CARRIED_TASK = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          carried_count: Helpers::Schema::INTEGER,
          sprint_on: Helpers::Schema::DAY,
        },
      ).freeze
      CREDITS = "who did the work; the owner when none is set"
      DAILY = "every day of the period, whatever the focus, with the tasks done, commits, seconds worked and " \
              "journal entries on it"
      DONE_TASK = Helpers::Schema.object(
        {
          id: Helpers::Schema::INTEGER,
          title: Helpers::Schema::STRING,
          worked_seconds: Helpers::Schema::INTEGER,
          contributors: Helpers::Schema.list(Task::CONTRIBUTOR).merge(description: CREDITS),
        },
      ).freeze
      RECORD = Helpers::Schema.object(
        { id: Helpers::Schema::INTEGER, date: Helpers::Schema::DAY, name: Helpers::Schema::STRING },
      ).freeze

      SCHEMA = Helpers::Schema.object(
        {
          period: { type: "string", enum: Blog::Types::ReviewPeriod.values },
          from: Helpers::Schema::DAY,
          to: Helpers::Schema::DAY,
          focus: Helpers::Schema.nullable(Helpers::Schema::DAY).merge(description: FOCUS),
          days: Helpers::Schema.list(
            Helpers::Schema.object(
              {
                date: Helpers::Schema::DAY,
                done: Helpers::Schema::INTEGER,
                commits: Helpers::Schema::INTEGER,
                worked_seconds: Helpers::Schema::INTEGER,
                journal: Helpers::Schema::INTEGER,
              },
            ),
          ).merge(description: DAILY),
          totals: Helpers::Schema.object(
            {
              done: Helpers::Schema::INTEGER,
              carried: Helpers::Schema::INTEGER,
              worked_seconds: Helpers::Schema::INTEGER,
              commits: Helpers::Schema::INTEGER,
            },
          ),
          done: Helpers::Schema.list(
            Helpers::Schema.object(
              {
                date: Helpers::Schema::DAY,
                tasks: Helpers::Schema.list(DONE_TASK),
              },
            ),
          ),
          carried: Helpers::Schema.list(CARRIED_TASK),
          posts: Helpers::Schema.list(RECORD),
          social_posts: Helpers::Schema.list(RECORD),
          journal: Helpers::Schema.object(
            {
              entries: Helpers::Schema.list(RECORD),
              words: Helpers::Schema::INTEGER,
              streak: Helpers::Schema::INTEGER,
            },
          ),
          commits: Helpers::Schema.list(
            Helpers::Schema.object(
              {
                repo: Helpers::Schema::STRING,
                commits: Helpers::Schema::INTEGER,
                additions: Helpers::Schema::INTEGER,
                deletions: Helpers::Schema::INTEGER,
              },
            ),
          ),
          decisions: Helpers::Schema.list(
            Helpers::Schema.object(
              {
                id: Helpers::Schema::INTEGER,
                title: Helpers::Schema::STRING,
                outcome: { type: "string", enum: OUTCOMES },
                chosen: Helpers::Schema.nullable(Helpers::Schema::STRING),
                reason: Helpers::Schema::STRING,
                date: Helpers::Schema::DAY,
              },
            ),
          ),
          worked: Helpers::Schema.list(
            Helpers::Schema.object({ date: Helpers::Schema::DAY, seconds: Helpers::Schema::INTEGER }),
          ),
          earlier: Helpers::Schema.list(
            Helpers::Schema.object(
              {
                type: { type: "string", enum: REMEMBERED },
                id: Helpers::Schema::INTEGER,
                date: Helpers::Schema::DAY,
                name: Helpers::Schema::STRING,
              },
            ),
          ).merge(description: EARLIER),
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

      def days(review) = review.days.map { |date, counts| { date: day(date), **counts } }

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

      def earlier(review) = review.earlier.map { { type: it.type, **record(it) } }

      def focus(review) = review.focus&.then { day(it) }

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

      def record(found) = { id: found.source_id, date: day(found.occurred_on), name: found.name }

      def records(found) = found.map { record(it) }
    end
  end
end
