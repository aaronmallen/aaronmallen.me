# frozen_string_literal: true

require "dry/monads"
require "sidekiq"

module Blog
  class Job
    DEFAULT_QUEUE = "default"

    include Dry::Monads[:result]
    include Sidekiq::Job
  end
end
