# frozen_string_literal: true

module Services
  module Operations
    class ResealCredentials
      include Deps["repos.app_mutations", "repos.connection_mutations"]

      def call(encryptor = Services::Encryptor.new)
        unreadable = 0
        resealed = [app_mutations, connection_mutations].sum do |repo|
          repo.reseal do |sealed|
            encryptor.reseal(sealed)
          rescue Services::Encryptor::Invalid
            unreadable += 1
            nil
          end
        end
        { resealed:, unreadable: }
      end
    end
  end
end
