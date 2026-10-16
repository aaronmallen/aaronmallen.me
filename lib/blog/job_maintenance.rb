# frozen_string_literal: true

require "sidekiq"

module Blog
  class JobMaintenance
    include Sidekiq::ServerMiddleware

    def initialize(flag)
      @flag = flag
    end

    def call(_job, _payload, _queue) = File.exist?(@flag) || yield
  end
end
