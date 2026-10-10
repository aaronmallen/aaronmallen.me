# frozen_string_literal: true

module Blog
  module UI
    class Component < Phlex::Hanami::Component
      include Phlex::Hanami::Props
      include Components
      include Wording

      OUTBOUND = { target: "_blank", rel: "noopener noreferrer" }.freeze
    end
  end
end
