# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class SessionRead < Component
          prop :read, Blog::Types::Instance(ROM::Struct)

          def view_template
            div(class: "agent-read") do
              span(class: "agent-read-time") { l(Blog::TimeZone.local(@read.read_at), format: :clock) }
              whitespace
              next span(class: "record-link-title") { t(".deleted") } unless @read.memory_file_id

              a(class: "record-link-title", href: path(:admin_memory_file, id: @read.memory_file_id)) do
                span(class: "agent-read-scope") { @read.scope }
                plain " #{@read.path}"
              end
            end
          end
        end
      end
    end
  end
end
