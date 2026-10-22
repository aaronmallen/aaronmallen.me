# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class SessionDrawer < Component
          ID = "agent-session"
          OPS = Blog::Types::MemoryEventOp.values.to_h { [it, ".ops.#{it}"] }.freeze
          SHOW = { dialog_show: true }.freeze

          prop :session, Blog::Types::Instance(ROM::Struct)
          prop :project, Blog::Types::String.optional
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :memory_changes, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :artifacts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Dialog(id: ID, title:, class: "wide", hidden: false, data: SHOW) do
              h3(class: "agent-session-title") { @session.title }
              p(class: "task-meta agent-session-meta") { meta }
              lists
            end
          end

          private

          def artifact(version)
            href = path(:admin_artifact, id: version.artifact_id, version: version.number)

            a(class: "record-link-title", href:) do
              span(class: "meta") { "#{t('.version', id: version.artifact_id, number: version.number)} " }
              plain version.title
            end
          end

          def change(event)
            text = event.text || event.was_text

            a(class: "agent-change", href: memory_file(event.memory_file_id)) do
              span(class: "meta") { t(OPS.fetch(event.op), path: event.path) }
              span(class: "agent-change-text") { text } if text
            end
          end

          def clock(time) = l(Blog::TimeZone.local(time), format: :clock)

          def index_line(line)
            id = line.memory_file_id

            MemoryLine(
              file: line, facts: line.fact_count, href: (memory_file(id) if id), path: (t(".deleted") unless id),
            )
          end

          def legacy
            Field(label: t(".loaded")) do
              Hint { t(".before") }
              ul(class: "record-link-list") do
                @session.agent_session_loads.each { |load| li(class: "record-link-row") { loaded(load) } }
              end
            end
          end

          def legacy?
            @session.agent_session_loads.any? &&
              [@session.agent_session_index_lines, @session.agent_session_searches, @session.agent_session_reads]
                .all?(&:empty?)
          end

          def list(label, rows, empty: t(".none"))
            Field(label:) do
              next Hint { empty } if rows.empty?

              ul(class: "record-link-list") { rows.each { |found| li(class: "record-link-row") { yield(found) } } }
            end
          end

          def lists
            list(t(".tasks"), @tasks) { task(it) } unless @tasks.empty?
            reads
            writes
          end

          def loaded(load) = a(class: "record-link-title", href: memory_file(load.memory_file_id)) { load.path }

          def memory_file(id) = path(:admin_memory_file, id:)

          def meta
            span { t(".who", agent: @session.agent, model: Helpers::AgentBrand.model(@session.model)) }
            span { t(".via", client: @session.client) } if @session.client
            href = path(:admin_agent_sessions, project: @session.project_id)
            a(href:, class: "tap-target") { IconLabel(icon: SessionRow::PROJECT_ICON) { @project } } if @project
            repo
            span { period }
          end

          def period
            from = clock(@session.started_at)
            return t(".running", from:) unless @session.ended_at

            elapsed = Blog::Helpers::Figures.elapsed(@session.ended_at - @session.started_at)
            t(".span", from:, to: clock(@session.ended_at), elapsed:)
          end

          def reads
            return legacy if legacy?

            list(t(".index"), @session.agent_session_index_lines) { index_line(it) }
            searches = @session.agent_session_searches
            list(t(".searches"), searches, empty: t(".no_searches")) { |search| SessionSearch(search:) }
            list(t(".read"), @session.agent_session_reads, empty: t(".no_reads")) { |read| SessionRead(read:) }
          end

          def repo
            return unless @session.repo

            span do
              Icon("fa-brands fa-github")
              whitespace
              plain @session.branch ? t(".branch", repo: @session.repo, branch: @session.branch) : @session.repo
            end
          end

          def task(found)
            a(class: "record-link-title", href: path(:admin_task, id: found.id)) do
              span(class: "meta") { "#{RecordKey.key(found.id)} " }
              plain found.title
            end
          end

          def title = t(".title", date: l(Blog::TimeZone.local_date(@session.started_at), format: :medium))

          def writes
            list(t(".changed"), @memory_changes) { change(it) }
            list(t(".written"), @artifacts) { artifact(it) }
          end
        end
      end
    end
  end
end
