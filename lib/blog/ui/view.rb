# frozen_string_literal: true

module Blog
  module UI
    class View < Phlex::Hanami::View
      include Phlex::Hanami::Props
      include Components
      include Wording

      def self.accepted_input(input)
        props.each_value.any? { it.kind == :** } ? input : input.slice(*props.keys)
      end

      private_class_method :accepted_input
    end
  end
end
