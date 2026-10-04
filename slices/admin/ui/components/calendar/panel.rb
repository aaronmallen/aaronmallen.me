# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class Panel < Component
          MOVES = { post: :admin_move_calendar_post, social: :admin_move_calendar_social_post }.freeze
          POSTED = Blog::Types::SocialPostStatus["posted"]
          POSTED_QUEUE = Blog::Types::SocialQueue["posted"]
          QUEUED = Blog::Types::SocialQueue["queued"]
          SCHEDULED = "scheduled"
          STATUSES = {
            "canceled" => ".statuses.canceled",
            "done" => ".statuses.done",
            "in_progress" => ".statuses.in_progress",
            "open" => ".statuses.open",
            "posted" => ".statuses.posted",
            "published" => ".statuses.published",
            "scheduled" => ".statuses.scheduled",
          }.freeze
          TEXT_LIMIT = 80

          prop :day, Blog::Types::Instance(API::Queries::Calendar::Day)
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :today, Blog::Types::Date

          def view_template
            Card(label: t(".label"), title: l(date, format: :full), **attributes) do
              next Empty { t(".empty") } if empty?

              sprint
              posts
              social_posts
              journal
            end
          end

          private

          def attributes
            { id: "calendar-day", class: "cal-panel", tabindex: "-1", data: { calendar_panel: date.iso8601 } }
          end

          def date = @day.date

          def dated(record, time)
            t(".dated", status: status(record), time: l(Blog::TimeZone.local(time), format: :clock))
          end

          def empty? = !@day.sprint && @day.posts.empty? && @day.social_posts.empty? && !@day.journal

          def entry(kind, record, item)
            return ListItem(**item) unless record.status == SCHEDULED

            ListItem(**item) { move_form(kind, record.id, item[:title]) }
          end

          def group(title, &)
            section(class: "cal-group") do
              h3(class: "cal-group-title") { title }
              div(class: "cal-group-items", &)
            end
          end

          def journal
            return unless @day.journal

            group(t(".journal")) { ListItem(title: t(".journal_entry"), href: path(:admin_journal, to: date.iso8601)) }
          end

          def move_form(kind, id, title)
            field = "cal-move-#{kind}-#{id}"

            Form(action: path(MOVES.fetch(kind), id:), class: "cal-move") do
              input(type: "hidden", name: "day", value: date.iso8601)
              label(class: "sr-only", for: field) { t(".move_to", title:) }
              Input(type: "date", id: field, name: "to", min: @today.iso8601, value: date.iso8601)
              Button(type: "submit", small: true) { t(".move") }
            end
          end

          def post_item(post)
            { title: post.title, href: path(:admin_edit_post, id: post.id), sub: dated(post, post.published_at) }
          end

          def posts
            return if @day.posts.empty?

            group(t(".posts")) { @day.posts.each { entry(:post, it, post_item(it)) } }
          end

          def social_href(social_post)
            return path(:admin_social, filter: POSTED_QUEUE) if social_post.status == POSTED

            path(:admin_social, filter: QUEUED, edit: social_post.id)
          end

          def social_item(social_post)
            {
              title: Blog::Truncation.cut(social_post.parts.first&.body.to_s, keep: TEXT_LIMIT),
              href: social_href(social_post),
              sub: dated(social_post, social_post.posted_at),
            }
          end

          def social_posts
            return if @day.social_posts.empty?

            group(t(".social_posts")) { @day.social_posts.each { entry(:social, it, social_item(it)) } }
          end

          def sprint
            found = @day.sprint
            return unless found

            group(t(".sprint", tasks: t(".tasks", count: found.task_count))) do
              next Empty { t(".no_tasks") } if @tasks.empty?

              @tasks.each { ListItem(title: it.title, href: path(:admin_task, id: it.id), sub: status(it)) }
            end
          end

          def status(record) = t(STATUSES.fetch(record.status))
        end
      end
    end
  end
end
