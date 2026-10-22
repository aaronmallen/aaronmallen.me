# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryIndex < Component
          prop :project, Blog::Types::Integer.optional
          prop :projects, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :files, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :keep, Blog::Types::Hash

          def view_template
            Card(title: t(".title")) do
              project_form
              Hint { dotted(t(".lines", count: @files.size), t(".behind", count: @files.sum { it.facts.size })) }
              ul(class: "record-link-list") { @files.each { |file| li(class: "record-link-row") { link(file) } } }
              Hint { t(".tasks") }
            end
          end

          private

          def link(file)
            MemoryLine(file:, facts: file.facts.size, href: path(:admin_memory_file, id: file.id))
          end

          def options = @projects.to_h { [it.id.to_s, it.name] }

          def project_form
            AutoForm(action: path(:admin_memory_files)) do
              HiddenFields(values: @keep)
              Field(label: t(".working_in"), id: "memory-index-project") do |control|
                Select(**control, name: "project", options:, selected: @project&.to_s)
              end
              noscript { Button(type: "submit", small: true) { t(".show") } }
            end
          end
        end
      end
    end
  end
end
