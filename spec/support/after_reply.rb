# frozen_string_literal: true

module Spec
  module AfterReply
    def finishes = @finishes ||= []

    def replies = @replies ||= []

    def reply
      replies.shift(replies.size).each(&:call)
      finishes.shift(finishes.size).reverse_each { it.call(nil, nil, nil, nil) }
    end

    def serve_like_puma
      env(Blog::RequestTimer::AFTER_REPLY, replies)
      env(Rack::RACK_RESPONSE_FINISHED, finishes)
    end
  end
end

RSpec.configure do |config|
  config.include Spec::AfterReply, type: :request
end
