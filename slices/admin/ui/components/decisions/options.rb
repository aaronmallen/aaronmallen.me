# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Decisions
        class Options < Component
          prop :decision, Blog::Types::Instance(ROM::Struct)
          prop :form, Blog::Types::Hash

          def view_template
            Card(title: t(".title")) do |card|
              card.side { span(class: "card-note") { @decision.options.size.to_s } }
              list
              add if @decision.open?
            end
          end

          private

          def add
            form = @form[:name] == :add_option ? @form : Blog::Constants::EMPTY_HASH

            details(class: "decision-add", open: form.any?) do
              summary(class: "decision-add-toggle") { t(".add") }
              OptionForm(decision: @decision, params: form[:params], errors: form.fetch(:errors, {}))
            end
          end

          def chosen
            Pill(color: :green, icon: "fa-solid fa-check") { t(".chosen") }
          end

          def chosen?(option) = option.id == @decision.resolved_option_id

          def edit(option)
            mine = mine?(option)

            details(class: "comment-edit", open: mine) do
              summary(class: "btn sm") { t(".edit") }
              OptionForm(
                decision: @decision, option:, params: (@form[:params] if mine),
                errors: mine ? @form[:errors] : Blog::Constants::EMPTY_HASH,
              )
            end
          end

          def item(option)
            li(**item_attributes(option)) do
              div(class: "decision-option-head") do
                span(class: "decision-option-title") { option.title }
                chosen if chosen?(option)
                div(class: "comment-acts") { edit(option) }
              end
              div(class: "markdown-body post-body decision-option-body") do
                raw(safe(::Tasks::Markdown.to_html(option.body).strip))
              end
            end
          end

          def item_attributes(option)
            { class: ["decision-option", ("chosen" if chosen?(option))], id: "decision-option-#{option.id}",
              data: { decision_option: option.id } }
          end

          def list
            return Hint { t(".empty") } if @decision.options.empty?

            ol(class: "decision-options") { @decision.options.each { item(it) } }
          end

          def mine?(option) = @form[:name] == :option && @form[:id] == option.id
        end
      end
    end
  end
end
