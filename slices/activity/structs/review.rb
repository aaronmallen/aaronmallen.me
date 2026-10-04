# frozen_string_literal: true

module Activity
  module Structs
    Review = Data.define(
      :period, :from, :to, :done, :carried, :posts, :social_posts, :journal, :commits, :decisions, :worked,
    ) do
      def worked_seconds = worked.values.sum
    end
  end
end
