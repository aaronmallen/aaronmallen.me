# frozen_string_literal: true

module Services
  module Operations
    class SaveApp < Operation
      include Deps["repos.app_mutations"]

      def call(**) = app_mutations.replace(**)
    end
  end
end
