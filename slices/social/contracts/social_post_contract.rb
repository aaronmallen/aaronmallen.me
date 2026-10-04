# frozen_string_literal: true

module Social
  module Contracts
    class SocialPostContract < Blog::Contract
      params do
        required(:parts).value(Blog::Types::TextList, :filled?)
        required(:targets).value(Blog::Types::Normalized::Networks, :filled?)
        required(:status).value(Blog::Types::SocialPostStatus)
        optional(:post_id).maybe(:integer)
        optional(:posted_at).maybe(:time)
      end

      rule(:parts).validate(:without_controls, :visible)
    end
  end
end
