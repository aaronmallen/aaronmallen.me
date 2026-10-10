# frozen_string_literal: true

module Blog
  module UI
    module Components
      class HiddenFields < Component
        prop :values, Blog::Types::Hash

        def view_template
          @values.each { |name, value| input(type: "hidden", name: name.to_s, value:) }
        end
      end
    end
  end
end
