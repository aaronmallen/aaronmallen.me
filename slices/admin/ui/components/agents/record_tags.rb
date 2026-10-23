# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class RecordTags < Component
          SESSION = :agent_session

          prop :tags, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :kind, Blog::Types::Symbol
          prop :id, Blog::Types::Integer
          prop :project_key, Blog::Types::String.optional

          def view_template
            Field(label: t(".label")) do
              div(class: "agent-tags") do
                @tags.each { pill(it) }
                add
              end
            end
          end

          private

          def add
            details(class: "nt-add") do
              summary(class: "nt-ta-add") do
                Icon("fa-solid fa-tag")
                plain @tags.empty? ? t(".add_tags") : t(".add")
              end
              Form(action: path(:"admin_tag_#{@kind}", id: @id)) do
                HiddenFields(values: { return_to: })
                input(
                  class: "nt-ti", type: "text", name: "tag", autocomplete: "off", placeholder: t(".placeholder"),
                  aria: { label: t(".new") },
                )
              end
            end
          end

          def pill(tag)
            span(class: "nt-tg") do
              Tag(tag:, project_key: @project_key)
              Form(action: path(:"admin_untag_#{@kind}", id: @id)) do
                HiddenFields(values: { tag: tag.name, return_to: })
                button(type: "submit", class: "nt-x", aria: { label: t(".remove", tag: tag.name) }) { Icon(:close) }
              end
            end
          end

          def return_to
            @kind == SESSION ? path(:admin_agent_sessions, session: @id) : path(:"admin_#{@kind}", id: @id)
          end
        end
      end
    end
  end
end
