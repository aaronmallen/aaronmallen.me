# frozen_string_literal: true

module Admin
  module Helpers
    module Short
      module_function

      def sha(sha) = sha.to_s[0, 7]

      def title(text) = Blog::Helpers::Truncation.cut(text, keep: 80)
    end
  end
end
