# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Today
        class Show < View
          include Components::Tasks

          DRAFT = Blog::Types::PostStatus["draft"]
          JOURNAL_KEY = "w"
          ORIGIN = Blog::Types::TaskOrigin["today"]
          QUEUED = Blog::Types::SocialQueue["queued"]
          UPCOMING = Blog::Types::TaskTab["upcoming"]

          prop :attention, Blog::Types::Hash
          prop :clients, Blog::Types::Integer
          prop :commits, Blog::Types::Hash
          prop :commit_totals, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :posts, Blog::Types::Hash, reader: :private
          prop :queue, Blog::Types::Hash, reader: :private
          prop :social, Blog::Types::Hash, reader: :private
          prop :sprint, Blog::Types::Hash
          prop :visitors, Blog::Types::Integer

          def view_template
            content_for(:title, t(".heading"))
            content_for(:task_origin, ORIGIN)

            div(class: "today") do
              PageHead(title: headline, kicker:, sub: lede) { head_actions }
              columns
            end
          end

          private

          def closed = sprint_tasks.count(&:closed?)

          def columns
            div(class: "g-main") do
              div(class: "today-main") { SprintPanel(**@sprint) }
              aside(class: "today-side") { side_cards }
            end
          end

          def head_actions
            Button(href: path(:admin_tasks, filter: UPCOMING), icon: "fa-regular fa-calendar") { t(".plan") }
            CreateButton(origin: ORIGIN)
          end

          def headline
            return t(".headline.empty") if sprint_tasks.empty?
            return t(".headline.clear") if open.empty?

            t(".headline.left", count: open.size)
          end

          def journal_line
            href = path(:admin_journal, write: Blog::Types::CHECKED)

            line(t(".journal"), href, data: { dialog_open: Components::Journal::WriteDialog::ID }) do
              plain t(".journal_count", count: @entries.size)
              whitespace
              kbd(class: "kbd", aria: { hidden: "true" }) { JOURNAL_KEY }
            end
          end

          def kicker = dotted(l(@sprint[:date], format: :weekday), l(Blog::TimeZone.local(Time.now), format: :clock))

          def lede
            return t(".lede.empty") if sprint_tasks.empty?
            return t(".lede.clear", count: closed) if open.empty?

            t(".lede.open", lead: lede_lead, done: closed, total: sprint_tasks.size)
          end

          def lede_lead
            task = open.find(&:in_progress?) || open.first
            lead = t(task.in_progress? ? ".lede.doing" : ".lede.next", task: task.title)
            return lead if task.carried_count.zero?

            t(".lede.carried", lead:, count: task.carried_count)
          end

          def line(label, href, data: nil, &)
            a(class: "today-line", href:, data:) do
              span { label }
              span(class: "today-line-value", &)
            end
          end

          def next_up
            [
              *posts[:scheduled].first(1).map { [it.published_at, path(:admin_edit_post, id: it.id)] },
              *social[:scheduled].first(1).map { [it.posted_at, path(:admin_social, filter: QUEUED)] },
            ].min_by(&:first)
          end

          def open = @open ||= sprint_tasks.reject(&:closed?)

          def quiet_lines
            Card(class: "today-quiet") do
              journal_line
              ships_next
              line(t(".drafts"), path(:admin_posts, status: DRAFT)) { t(".draft_count", count: posts[:drafts].size) }
              site_lines
            end
          end

          def ships_next
            at, href = next_up
            return line(t(".ships_next"), path(:admin_calendar)) { t(".nothing_scheduled") } unless at

            line(t(".ships_next"), href) do
              Moment(at:)
              plain "#{DOT}#{t('.queued', count: queue[:count])}"
            end
          end

          def side_cards
            AttentionCard(**@attention)
            CommitsCard(**@commits, totals: @commit_totals)
            quiet_lines
          end

          def site_lines
            line(t(".visitors"), path(:admin_analytics)) { t(".visitor_count", count: @visitors) }
            line(t(".clients"), path(:admin_clients)) { t(".client_count", count: @clients) }
          end

          def sprint_tasks = @sprint[:tasks]
        end
      end
    end
  end
end
