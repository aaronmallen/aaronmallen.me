# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Agents
        class ArtifactType < Component
          Look = Data.define(:tone, :icon, :text)

          LOOKS = {
            "plan" => Look.new(tone: :blue, icon: "fa-solid fa-route", text: "text-mk-blue-text"),
            "spec" => Look.new(tone: :violet, icon: "fa-solid fa-ruler-combined", text: "text-mk-violet-text"),
            "research" => Look.new(tone: :green, icon: "fa-solid fa-flask", text: "text-mk-green-text"),
            "handoff" => Look.new(tone: :orange, icon: "fa-solid fa-right-left", text: "text-mk-orange-text"),
            "notes" => Look.new(tone: :sand, icon: "fa-regular fa-note-sticky", text: "text-mk-sand-text"),
            "review" => Look.new(tone: :pink, icon: "fa-solid fa-magnifying-glass", text: "text-mk-pink-text"),
            "postmortem" => Look.new(tone: :pink, icon: "fa-solid fa-heart-crack", text: "text-mk-pink-text"),
            "other" => Look.new(tone: nil, icon: "fa-regular fa-file", text: nil),
          }.freeze

          def self.look(type) = LOOKS.fetch(type)

          prop :type, Blog::Types::ArtifactType

          def view_template
            look = self.class.look(@type)

            ToneText(color: look.tone, icon: look.icon) { @type }
          end
        end
      end
    end
  end
end
