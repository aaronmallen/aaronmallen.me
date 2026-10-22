# frozen_string_literal: true

module Security
  module Operations
    class PruneAccessRecords
      KEEP_FOR = 90 * 24 * 60 * 60

      include Deps[
        device_mutations: "repos.device_mutations",
        sighting_mutations: "repos.sighting_mutations",
        sign_in_mutations: "repos.sign_in_mutations",
      ]

      def call(at: Time.now)
        sign_in_mutations.delete_before(at - KEEP_FOR)
        sighting_mutations.delete_last_seen_before(at - KEEP_FOR)
        device_mutations.delete_signed_in_before(at - Blog::DeviceCookie::LIFETIME)
      end
    end
  end
end
