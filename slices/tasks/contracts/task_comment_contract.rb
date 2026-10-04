# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskCommentContract < Blog::Contract
      params do
        required(:body).value(Blog::Types::TrimmedText, :filled?)
      end

      rule(:body).validate(:without_controls, :visible)
    end
  end
end
