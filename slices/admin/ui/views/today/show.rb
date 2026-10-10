# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Today
        class Show < View
          include Components::Tasks

          ORIGIN = Blog::Types::TaskOrigin["today"]
          UPCOMING = Blog::Types::TaskTab["upcoming"]

          prop :attention, Blog::Types::Hash
          prop :clients, Blog::Types::Integer
          prop :commits, Blog::Types::Hash
          prop :commit_totals, Blog::Types::Hash.map(Blog::Types::Symbol, Blog::Types::Integer)
          prop :entries, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :posts, Blog::Types::Hash
          prop :queue, Blog::Types::Hash
          prop :social, Blog::Types::Hash
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

          def open = @open ||= sprint_tasks.reject(&:closed?)

          def side_cards
            AttentionCard(**@attention)
            CommitsCard(**@commits, totals: @commit_totals)
            QuietCard(
              entries: @entries, posts: @posts, social: @social, queue: @queue, visitors: @visitors, clients: @clients,
            )
          end

          def sprint_tasks = @sprint[:tasks]
        end
      end
    end
  end
end
