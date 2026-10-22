# frozen_string_literal: true

module Security
  module Operations
    class DismissSignIn < Blog::Operation
      include Deps[sign_in_mutations: "repos.sign_in_mutations"]

      def call(id) = step affected(sign_in_mutations.dismiss(Blog::Types::IdParam[id]))
    end
  end
end
