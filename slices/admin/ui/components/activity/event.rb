# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Activity
        class Event < Component
          Type = Data.define(:icon, :color, :prose)

          COMMENT = Blog::Types::ActivityKind["comment"]
          COMMIT = Blog::Types::ActivityKind["commit"]
          DECISION = Blog::Types::ActivityKind["decision"]
          DECISION_COMMENT = Blog::Types::ActivityKind["decision_comment"]
          JOURNAL = Blog::Types::ActivityKind["journal"]
          POST = Blog::Types::ActivityKind["post"]
          SOCIAL = Blog::Types::ActivityKind["social"]
          TASK = Blog::Types::ActivityKind["task"]
          WEBMENTION = Blog::Types::ActivityKind["webmention"]
          TYPES = {
            COMMIT => Type.new(icon: "fa-code-commit", color: :violet, prose: false),
            POST => Type.new(icon: "fa-file-lines", color: :green, prose: false),
            JOURNAL => Type.new(icon: "fa-feather", color: :sand, prose: true),
            SOCIAL => Type.new(icon: "fa-paper-plane", color: :blue, prose: true),
            TASK => Type.new(icon: "fa-circle-check", color: :orange, prose: false),
            COMMENT => Type.new(icon: "fa-comment", color: :orange, prose: true),
            DECISION => Type.new(icon: "fa-scale-balanced", color: :sand, prose: false),
            DECISION_COMMENT => Type.new(icon: "fa-comments", color: :sand, prose: true),
            WEBMENTION => Type.new(icon: "fa-at", color: :pink, prose: false),
          }.freeze
          POSTED = Blog::Types::SocialQueue["posted"]

          prop :event, Blog::Types::Instance(Structs::ActivityEvent)

          def view_template
            href = href_for

            if href
              a(class: "activity-event", href:) { row }
            else
              div(class: "activity-event") { row }
            end
          end

          private

          def clock = l(@event.occurred_at, format: :clock)

          def href_for
            case @event.type
            when COMMIT then path(:admin_commit, id: @event.source_id)
            when POST then path(:admin_edit_post, id: @event.source_id)
            when JOURNAL then "#{path(:admin_journal, to: @event.occurred_on)}##{Journal::Day.anchor(@event.occurred_on)}"
            when SOCIAL then path(:admin_social, filter: POSTED)
            when TASK, COMMENT, DECISION, DECISION_COMMENT then owner_href
            when WEBMENTION then path(:admin_webmentions)
            end
          end

          def name = @event.name_html ? raw(safe(@event.name_html)) : plain(@event.name)

          def named
            div(class: "activity-event-main") do
              span(class: ["activity-event-name", ("prose" if type.prose)]) { name }
              span(class: "activity-event-sub") { @event.sub_line }
            end
          end

          def owner_href = @event.decision_id ? path(:admin_decision, id: @event.decision_id) : task_href

          def row
            i(class: ["fa-solid", type.icon, "activity-icon", type.color.to_s], aria: { hidden: "true" })
            named
            stamp
          end

          def stamp
            time(class: "activity-event-time", datetime: "#{@event.occurred_on.iso8601}T#{clock}") { clock }
          end

          def task_href
            return path(:admin_tasks) if @event.type == TASK

            "#{path(:admin_task, id: @event.task_id)}#task-comment-#{@event.source_id}"
          end

          def type = TYPES.fetch(@event.type)
        end
      end
    end
  end
end
