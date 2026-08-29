# frozen_string_literal: true

module Tasks
  module Contracts
    class TaskTypeContract < Blog::Contract
      params do
        required(:name).value(Blog::Types::TrimmedText, :filled?)
        required(:color).maybe(Blog::Types::Nullable::TagColor)
        required(:icon).maybe(Blog::Types::Nullable::TaskTypeIcon)
      end

      rule(:name).validate(:without_controls)
    end
  end
end
