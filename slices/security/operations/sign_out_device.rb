# frozen_string_literal: true

module Security
  module Operations
    class SignOutDevice < Blog::Operation
      include Deps[device_mutations: "repos.device_mutations"]

      def call(id) = step affected(device_mutations.sign_out(Blog::Types::UuidParam[id]))
    end
  end
end
