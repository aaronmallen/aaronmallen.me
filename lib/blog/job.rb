# frozen_string_literal: true

require "dry/monads"
require "sidekiq"

module Blog
  class Job
    include Dry::Monads[:result]
    include Sidekiq::Job

    sidekiq_options retry: 3
  end
end
