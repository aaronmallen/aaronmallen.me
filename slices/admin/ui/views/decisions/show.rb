# frozen_string_literal: true

module Admin
  module UI
    module Views
      module Decisions
        class Show < View
          include Components::Decisions

          DROPPED = Blog::Types::DecisionStatus["dropped"]
          RESOLVED = Blog::Types::DecisionStatus["resolved"]

          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :form, Blog::Types::Hash
          prop :timeline, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :records, Blog::Types::Hash

          def view_template
            head
            div(class: "g-main", data: { decision_read: @decision.id }) do
              div(class: "decision-main") { main }
              aside(class: "decision-side") { side }
            end
          end

          private

          def chosen = @decision.options.find { it.id == @decision.resolved_option_id }

          def head
            PageHead(title: @decision.title, kicker: t(".kicker"), sub: lede) do
              BackLink(href: path(:admin_decisions, status: @decision.status)) { t(".back") }
              Status(status: @decision.status)
              Button(href: path(:admin_edit_decision, id: @decision.id), icon: "fa-regular fa-pen-to-square") do
                t(".edit")
              end
            end
          end

          def lede
            case @decision.status
              when RESOLVED then t(".chose", option: chosen.title)
              when DROPPED then t(".dropped")
            end
          end

          def linked
            id = @decision.id

            RecordLinks::Section(
              records: @records, kind: "decision", id:, find_path: path(:admin_decision, id:),
            )
          end

          def main
            problem
            Options(decision: @decision, form: @form)
            Closing(decision: @decision, form: @form)
            Comments(decision: @decision, entries: @timeline, form: @form)
          end

          def meta
            Card do
              p(class: "read-meta decision-meta") do
                RecordKey(kind: "decision", id: @decision.id)
                span { Stamped(text: t(".opened", date: Stamped::MARK), at: @decision.created_at, format: :day) }
                @decision.tags.each { Tag(tag: it) }
              end
            end
          end

          def problem
            Card(title: t(".problem")) do
              div(class: "markdown-body post-body") { raw(safe(::Tasks::Markdown.to_html(@decision.problem).strip)) }
            end
          end

          def side
            meta
            linked
            Timeline(decision: @decision, entries: @timeline)
          end
        end
      end
    end
  end
end
