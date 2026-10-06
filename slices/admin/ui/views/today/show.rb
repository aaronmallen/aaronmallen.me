# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Today
        class Show < View
          include Components::Tasks

          ORIGIN = Blog::Types::TaskOrigin["today"]
          QUEUE_KINDS = { posts: ".queue_posts", social_posts: ".queue_social_posts" }.freeze

          def initialize(
            attention:, commits:, commit_totals:, entries:, posts:, queue:, social:, sprint:, sync_failures:,
            visitors:, webmentions:, body: Blog::Constants::EMPTY_STRING, errors: Blog::Constants::EMPTY_HASH,
            tags: Blog::Constants::EMPTY_STRING
          )
            super()
            @attention = attention
            @commits = commits
            @commit_totals = commit_totals
            @journal = { body:, entries:, errors:, tags:, word_count: Blog::Figures.words(body) }
            @publishing = { posts:, queue:, social: }
            @sprint = sprint
            @sync_failures = sync_failures
            @visitors = visitors
            @webmentions = webmentions
          end

          def view_template
            content_for(:title, t(".heading"))
            content_for(:task_origin, ORIGIN)

            PageHead(title: l(@sprint[:date], format: :weekday), sub:) { head_actions }

            SyncFailures(failures: @sync_failures)

            Grid(columns: 4) { stats }

            SprintPanel(**@sprint)

            Grid(columns: 2) do
              SideStack { main_cards }
              SideStack { side_cards }
            end
          end

          private

          def commits_note = t(".commits_note", **@commit_totals)

          def head_actions
            CreateButton(origin: ORIGIN)
            Button(href: path(:admin_clients)) { t(".clients") }
            sign_out_form
          end

          def main_cards
            TodayJournalCard(**@journal)
            CommitsCard(**@commits)
          end

          def posts = @publishing[:posts]

          def queue = @publishing[:queue]

          def queue_kinds
            waiting = QUEUE_KINDS.select { |kind, _key| queue[kind].positive? }

            dotted(*waiting.map { |kind, key| t(key, count: queue[kind]) })
          end

          def queue_stat
            note = queue[:count].zero? ? t(".queue_note_empty") : queue_kinds

            Stat(key: t(".queue"), value: queue[:count], change: note)
          end

          def side_cards
            AttentionCard(rows: @attention)
            Components::Webmentions::PendingCard(**@webmentions) if @webmentions[:count].positive?
            ShipsNextCard(posts: posts[:scheduled], social_posts: social[:scheduled], summaries: social[:summaries])
            DraftsCard(posts: posts[:drafts], counts: posts[:draft_counts])
          end

          def sign_out_form
            Form(action: path(:admin_sign_out)) do
              Button(type: "submit") { t(".sign_out") }
            end
          end

          def social = @publishing[:social]

          def sprint_done = sprint_tasks.count(&:closed?)

          def sprint_open = sprint_tasks.size - sprint_done

          def sprint_stat
            note = sprint_tasks.empty? ? t(".sprint_empty") : t(".sprint_open", count: sprint_open)

            Stat(key: t(".sprint"), value: sprint_value, change: note, down: sprint_tasks.empty?)
          end

          def sprint_tasks = @sprint[:tasks]

          def sprint_value = t(".sprint_value", done: sprint_done, total: sprint_tasks.size)

          def stats
            sprint_stat
            Stat(key: t(".commits"), value: @commit_totals[:commits], change: commits_note)
            Stat(key: t(".webmentions"), value: @webmentions[:count], change: t(".webmentions_note"))
            queue_stat
            Stat(key: t(".visitors"), value: @visitors)
          end

          def sub
            dotted(
              t(".sub_tasks", done: sprint_done, total: sprint_tasks.size),
              t(".sub_commits", count: @commit_totals[:commits]),
              t(".sub_entries", count: @journal[:entries].size),
              t(".sub_scheduled", count: queue[:today]),
            )
          end
        end
      end
    end
  end
end
