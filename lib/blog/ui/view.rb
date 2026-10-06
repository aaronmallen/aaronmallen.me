# frozen_string_literal: true

module Blog
  module UI
    class View < Phlex::Hanami::View
      include Phlex::Hanami::Props
      include Components
      include Wording
    end
  end
end
