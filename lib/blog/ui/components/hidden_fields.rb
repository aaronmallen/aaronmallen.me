# frozen_string_literal: true

module Blog
  module UI
    module Components
      class HiddenFields < Component
        prop :values, Blog::Types::Hash

        def view_template
          @values.compact.each do |name, value|
            (value.is_a?(Array) ? value : [value]).each { input(type: "hidden", name: name.to_s, value: it) }
          end
        end
      end
    end
  end
end
