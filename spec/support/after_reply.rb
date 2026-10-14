# frozen_string_literal: true

module Spec
  module AfterReply
    def replies = @replies ||= []

    def reply = replies.shift(replies.size).each(&:call)

    def serve_like_puma = env(Blog::RequestTimer::AFTER_REPLY, replies)
  end
end

RSpec.configure do |config|
  config.include Spec::AfterReply, type: :request
end
