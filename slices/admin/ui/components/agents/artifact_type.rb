# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactType < Component
          ICONS = {
            "plan" => "fa-solid fa-route", "spec" => "fa-solid fa-ruler-combined", "research" => "fa-solid fa-flask",
            "handoff" => "fa-solid fa-right-left", "notes" => "fa-regular fa-note-sticky",
            "review" => "fa-solid fa-magnifying-glass", "postmortem" => "fa-solid fa-heart-crack",
            "other" => "fa-regular fa-file",
          }.freeze
          TONES = {
            "plan" => :blue, "spec" => :violet, "research" => :green, "handoff" => :orange, "notes" => :sand,
            "review" => :pink, "postmortem" => :pink,
          }.freeze

          prop :type, Blog::Types::ArtifactType

          def view_template
            span(class: ["task-mark", TONES[@type]]) do
              Icon(ICONS.fetch(@type))
              plain @type
            end
          end
        end
      end
    end
  end
end
