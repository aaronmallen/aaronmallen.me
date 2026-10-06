# frozen_string_literal: true

module Blog
  module UI
    class View < Phlex::Hanami::View
      include Components
      include Wording
    end
  end
end
