# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Options < Component
          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :form, Blog::Types::Hash

          def view_template
            Card(label: t(".label"), title: t(".title"), class: "task-comments") do
              list
              add if @decision.open?
            end
          end

          private

          def add
            form = @form[:name] == :add_option ? @form : Blog::Constants::EMPTY_HASH

            OptionForm(decision: @decision, params: form[:params], errors: form.fetch(:errors, {}))
          end

          def chosen
            Pill(color: :green) do
              i(class: "fa-solid fa-check", aria: { hidden: "true" })
              span { t(".chosen") }
            end
          end

          def chosen?(option) = option.id == @decision.resolved_option_id

          def edit(option)
            mine = mine?(option)

            details(class: "task-comment-edit", open: mine) do
              summary(class: "btn sm") { t(".edit") }
              OptionForm(
                decision: @decision, option:, params: (@form[:params] if mine),
                errors: mine ? @form[:errors] : Blog::Constants::EMPTY_HASH,
              )
            end
          end

          def item(option)
            li(class: "task-comment", id: "decision-option-#{option.id}", data: { decision_option: option.id }) do
              div(class: "task-comment-head") do
                span(class: "task-comment-author") { option.title }
                chosen if chosen?(option)
                div(class: "task-comment-acts") { edit(option) }
              end
              div(class: "task-body post-body task-comment-body") do
                raw(safe(::Tasks::Markdown.to_html(option.body).strip))
              end
            end
          end

          def list
            return Hint { t(".empty") } if @decision.options.empty?

            ol(class: "task-comment-list") { @decision.options.each { item(it) } }
          end

          def mine?(option) = @form[:name] == :option && @form[:id] == option.id
        end
      end
    end
  end
end
