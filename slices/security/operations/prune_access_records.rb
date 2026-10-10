# frozen_string_literal: true

module Security
  module Operations
    class PruneAccessRecords
      KEEP_FOR = 90 * 24 * 60 * 60

      include Deps[
        sighting_mutations: "repos.sighting_mutations",
        sign_in_mutations: "repos.sign_in_mutations",
      ]

      def call(at: Time.now)
        sign_in_mutations.delete_before(at - KEEP_FOR)
        sighting_mutations.delete_last_seen_before(at - KEEP_FOR)
      end
    end
  end
end
