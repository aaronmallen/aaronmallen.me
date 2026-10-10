# frozen_string_literal: true

module Contact
  module Operations
    class DeleteMessage < Blog::Operation
      include Deps[message_mutations: "repos.message_mutations"]

      def call(id) = step found(message_mutations.delete(id))
    end
  end
end
