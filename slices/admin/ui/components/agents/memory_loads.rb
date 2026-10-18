# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class MemoryLoads < Component
          prop :repo, Blog::Types::String.optional
          prop :repos, Blog::Types::Array.of(Blog::Types::String)
          prop :files, Blog::Types::Array.of(Blog::Types::Instance(ROM::Struct))
          prop :keep, Blog::Types::Hash

          def view_template
            Card(title: t(".title")) do
              repo_form
              Hint { dotted(t(".files", count: @files.size), t(".facts", count: @files.sum { it.facts.size })) }
              ul(class: "record-link-list") { @files.each { |file| li(class: "record-link-row") { link(file) } } }
              Hint { t(".tasks") }
            end
          end

          private

          def link(file)
            a(class: "record-link-title", href: path(:admin_memory_file, id: file.id)) do
              span(class: "meta") { "#{file.scope} " }
              plain file.path
            end
          end

          def repo_form
            AutoForm(action: path(:admin_memory_files)) do
              HiddenFields(values: @keep)
              Field(label: t(".working_in"), id: "memory-loads-repo") do |control|
                Select(**control, name: "repo", options: @repos.to_h { [it, it] }, selected: @repo)
              end
              noscript { Button(type: "submit", small: true) { t(".show") } }
            end
          end
        end
      end
    end
  end
end
