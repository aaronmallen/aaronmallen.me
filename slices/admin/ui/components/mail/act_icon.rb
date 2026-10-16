# frozen_string_literal: true

module Admin
  module UI
    module Components
      module Mail
        module ActIcon
          ICONS = {
            "archive" => :archive,
            "delete" => :trash,
            "inbox" => "fa-solid fa-inbox",
            "label" => "fa-solid fa-tag",
            "move" => "fa-solid fa-arrow-right",
            "read" => "fa-regular fa-envelope-open",
            "spam" => :ban,
            "star" => "fa-regular fa-star",
            "trash" => :trash,
            "unread" => "fa-regular fa-envelope",
            "unstar" => "fa-solid fa-star",
          }.freeze

          def self.[](act) = ICONS.fetch(act)
        end
      end
    end
  end
end
