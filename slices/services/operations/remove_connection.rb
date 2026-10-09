# frozen_string_literal: true

module Services
  module Operations
    class RemoveConnection < Operation
      include Deps["repos.connection_mutations"]

      def call(id) = step affected(connection_mutations.remove(id))
    end
  end
end
