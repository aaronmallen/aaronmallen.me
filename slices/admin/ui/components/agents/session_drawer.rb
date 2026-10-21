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
          prop :tasks, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :memory_changes, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :artifacts, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))

          def view_template
            Dialog(id: ID, title:, class: "wide", hidden: false, data: SHOW) do
              h3(class: "card-title") { @session.title }
              Hint { meta }
              lists
            end
          end

          private

          def artifact(version)
            href = path(:admin_artifact, id: version.artifact_id, version: version.number)

            a(class: "record-link-title", href:) do
              t(".version", id: version.artifact_id, number: version.number, title: version.title)
            end
          end

          def change(event)
            div(class: "agent-change") do
              a(class: "record-link-title", href: memory_file(event.memory_file_id)) do
                t(OPS.fetch(event.op), path: event.path)
              end
              text = event.text || event.was_text
              p(class: "agent-change-text") { text } if text
            end
          end

          def clock(time) = l(Blog::TimeZone.local(time), format: :clock)

          def index_line(line)
            div(class: "agent-change") do
              if line.memory_file_id
                a(class: "record-link-title", href: memory_file(line.memory_file_id)) { line.path }
              else
                span(class: "record-link-title") { t(".deleted") }
              end
              p(class: "agent-change-text") do
                dotted(line.scope, t(".facts", count: line.fact_count), line.description)
              end
            end
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
            dotted(
              t(".who", agent: @session.agent, model: Helpers::AgentBrand.model(@session.model)),
              (t(".via", client: @session.client) if @session.client), repo, period,
            )
          end

          def period
            from = clock(@session.started_at)
            return t(".running", from:) unless @session.ended_at

            elapsed = Blog::Helpers::Figures.elapsed(@session.ended_at - @session.started_at)
            t(".span", from:, to: clock(@session.ended_at), elapsed:)
          end

          def reads
            list(t(".index"), @session.agent_session_index_lines) { index_line(it) }
            searches = @session.agent_session_searches
            list(t(".searches"), searches, empty: t(".no_searches")) { |search| SessionSearch(search:) }
            list(t(".loaded"), @session.agent_session_loads) { loaded(it) }
          end

          def repo
            return unless @session.repo

            @session.branch ? t(".branch", repo: @session.repo, branch: @session.branch) : @session.repo
          end

          def task(found)
            a(class: "record-link-title", href: path(:admin_task, id: found.id)) { found.title }
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
