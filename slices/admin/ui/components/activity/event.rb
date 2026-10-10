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
          PULL_REQUEST_CLOSED = Blog::Types::ActivityKind["pull_request_closed"]
          PULL_REQUEST_MERGED = Blog::Types::ActivityKind["pull_request_merged"]
          PULL_REQUEST_OPENED = Blog::Types::ActivityKind["pull_request_opened"]
          SESSION = Blog::Types::ActivityKind["session"]
          SOCIAL = Blog::Types::ActivityKind["social"]
          TASK = Blog::Types::ActivityKind["task"]
          WEBMENTION = Blog::Types::ActivityKind["webmention"]
          KINDS = Blog::Helpers::RecordKinds
          PAGES = {
            COMMIT => KINDS.fetch("commit").route,
            POST => KINDS.fetch("post").route,
            PULL_REQUEST_OPENED => KINDS.fetch("pull_request").route,
            PULL_REQUEST_MERGED => KINDS.fetch("pull_request").route,
            PULL_REQUEST_CLOSED => KINDS.fetch("pull_request").route,
          }.freeze
          TYPES = {
            COMMIT => Type.new(icon: KINDS.icon("commit"), color: :violet, prose: false),
            PULL_REQUEST_OPENED => Type.new(icon: KINDS.icon("pull_request"), color: :violet, prose: false),
            PULL_REQUEST_MERGED => Type.new(icon: "fa-code-merge", color: :violet, prose: false),
            PULL_REQUEST_CLOSED => Type.new(icon: "fa-circle-xmark", color: :violet, prose: false),
            POST => Type.new(icon: KINDS.icon("post"), color: :green, prose: false),
            JOURNAL => Type.new(icon: KINDS.icon("journal_entry"), color: :sand, prose: true),
            SOCIAL => Type.new(icon: KINDS.icon("social_post"), color: :blue, prose: true),
            TASK => Type.new(icon: "fa-circle-check", color: :orange, prose: false),
            SESSION => Type.new(icon: "fa-clock", color: :orange, prose: false),
            COMMENT => Type.new(icon: "fa-comment", color: :orange, prose: true),
            DECISION => Type.new(icon: KINDS.icon("decision"), color: :sand, prose: false),
            DECISION_COMMENT => Type.new(icon: "fa-comments", color: :sand, prose: true),
            WEBMENTION => Type.new(icon: "fa-at", color: :pink, prose: false),
          }.freeze
          ANCHORS = { COMMENT => "task-comment", SESSION => "task-session" }.freeze
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
              when *PAGES.keys then path(PAGES.fetch(@event.type), id: @event.source_id)
              when JOURNAL then KINDS.journal_day(routes, @event.occurred_on)
              when SOCIAL then path(:admin_social, filter: POSTED)
              when TASK, SESSION, COMMENT, DECISION, DECISION_COMMENT then owner_href
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
            Icon(["fa-solid", type.icon, "activity-icon", type.color.to_s])
            named
            stamp
          end

          def stamp
            time(class: "activity-event-time", datetime: "#{@event.occurred_on.iso8601}T#{clock}") { clock }
          end

          def task_href
            return path(:admin_tasks) if @event.type == TASK

            "#{path(:admin_task, id: @event.task_id)}##{ANCHORS.fetch(@event.type)}-#{@event.source_id}"
          end

          def type = TYPES.fetch(@event.type)
        end
      end
    end
  end
end
