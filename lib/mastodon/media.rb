# frozen_string_literal: true

module Mastodon
  module Media
    PATH = "/api/v2/media"
    PROCESSING = [202, 206].freeze
    SECONDS = 1
    STATUS_PATH = "/api/v1/media"
    TRIES = 10

    def self.processed(uploaded)
      id = uploaded.body.fetch("id") { raise Error, "Mastodon answered #{PATH} without a media ID" }.to_s
      status = uploaded.status

      TRIES.times do
        break unless PROCESSING.include?(status)

        sleep(SECONDS)
        status = yield("#{STATUS_PATH}/#{id}")
      end
      raise Error, "Mastodon did not finish processing media #{id}" if PROCESSING.include?(status)

      id
    end
  end
end
