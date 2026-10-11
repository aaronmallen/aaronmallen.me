# frozen_string_literal: true

module Services
  module Operations
    class ChangeConnection
      include Deps["repos.connection_mutations"]

      def call(id, **) = connection_mutations.change(id, **)
    end
  end
end
