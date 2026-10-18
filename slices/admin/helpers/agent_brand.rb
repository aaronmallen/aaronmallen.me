# frozen_string_literal: true

module Admin
  module Helpers
    module AgentBrand
      BRANDS = {
        /\Aclaude/ => "Anthropic",
        /\A(gpt|o\d|codex)/ => "OpenAI",
        /\Agemini/ => "Google",
        /\A(mistral|codestral)/ => "Mistral",
      }.freeze
      SPACE = " "

      module_function

      def model(model) = [of(model), model].compact.join(SPACE)

      def of(model) = BRANDS.find { |pattern, _| pattern.match?(model) }&.last
    end
  end
end
