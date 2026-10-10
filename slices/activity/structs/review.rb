# frozen_string_literal: true

module Activity
  module Structs
    Review = Data.define(
      :period, :from, :to, :focus, :days, :done, :carried, :posts, :social_posts, :journal, :commits, :decisions,
      :worked, :earlier,
    ) do
      def worked_seconds = worked.values.sum
    end
  end
end
