# frozen_string_literal: true

require "sidekiq"

module Blog
  class JobMaintenance
    include Sidekiq::ServerMiddleware

    DELAY = 300

    def initialize(flag)
      @flag = flag
    end

    def call(job, payload, _queue)
      return yield unless File.exist?(@flag)

      Sidekiq::Client.push(payload.merge("at" => Time.now.to_f + DELAY)) unless job.is_a?(ScheduledJob)
    end
  end
end
