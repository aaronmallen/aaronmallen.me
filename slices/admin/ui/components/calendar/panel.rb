# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Calendar
        class Panel < Component
          MOVES = {
            post: :admin_move_calendar_post,
            social: :admin_move_calendar_social_post,
            task: :admin_move_calendar_task,
          }.freeze
          POSTED = Blog::Types::SocialPostStatus["posted"]
          POSTED_QUEUE = Blog::Types::SocialQueue["posted"]
          QUEUED = Blog::Types::SocialQueue["queued"]
          SCHEDULED = "scheduled"
          STATUSES = {
            Blog::Types::PostStatus["published"] => ".statuses.published",
            Blog::Types::PostStatus["scheduled"] => ".statuses.scheduled",
            Blog::Types::SocialPostStatus["posted"] => ".statuses.posted",
            **Helpers::TaskStatuses::NAMES,
          }.freeze

          prop :day, Blog::Types::Instance(API::Structs::CalendarDay)
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :today, Blog::Types::Date

          def view_template
            Card(label: t(".label"), title: l(date, format: :full), **attributes) do
              next Empty { t(".empty") } if empty?

              posts
              social_posts
              sprint
              journal
            end
          end

          private

          def attributes
            { id: "calendar-day", class: "cal-panel", tabindex: "-1", data: { calendar_panel: date.iso8601 } }
          end

          def date = @day.date

          def dated(record, at)
            Stamped(text: t(".dated", status: status(record), time: Stamped::MARK), at:, format: :clock)
          end

          def empty? = !@day.sprint && @day.posts.empty? && @day.social_posts.empty? && !@day.journal

          def entry(kind, record, item, movable: record.status == SCHEDULED)
            at = item[:at]

            ListItem(**item.except(:at), data: { calendar_item: "#{kind}-#{record.id}" }) do |row|
              row.meta { p(class: "li-sub") { dated(record, at) } } if at
              move_form(kind, record.id, item[:title]) if movable
            end
          end

          def grip(title)
            label = t(".drag", title:)

            Button(
              small: true, class: "cal-grip", hidden: true, label:, data: grip_data,
              icon: "fa-solid fa-grip-vertical",
            )
          end

          def grip_data
            { calendar_grip: "", calendar_failed: t(".failed"), calendar_past: t("calendar_page.toasts.past") }
          end

          def group(title, &)
            section(class: "cal-group") do
              h3(class: "cal-group-title") { title }
              div(&)
            end
          end

          def journal
            return unless @day.journal

            group(t(".journal")) { ListItem(title: t(".journal_entry"), href: path(:admin_journal, to: date.iso8601)) }
          end

          def move_form(kind, id, title)
            field = "cal-move-#{kind}-#{id}"

            Form(action: path(MOVES.fetch(kind), id:), class: "cal-move") do
              grip(title)
              input(type: "hidden", name: "day", value: date.iso8601)
              label(class: "sr-only", for: field) { t(".move_to", title:) }
              Input(type: "date", id: field, name: "to", min: @today.iso8601, value: date.iso8601)
              button(type: "submit", class: "bt sm") { t(".move") }
            end
          end

          def post_item(post)
            { title: post.title, href: path(:admin_edit_post, id: post.id), at: post.published_at }
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
              title: Admin::Short.title(social_post.parts.first&.body.to_s),
              href: social_href(social_post),
              at: social_post.posted_at,
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

              @tasks.each { entry(:task, it, task_item(it), movable: !it.closed?) }
            end
          end

          def status(record) = t(STATUSES.fetch(record.status))

          def task_item(task) = { title: task.title, href: path(:admin_task, id: task.id), sub: status(task) }
        end
      end
    end
  end
end
