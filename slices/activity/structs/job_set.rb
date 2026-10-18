# frozen_string_literal: true

module Activity
  module Structs
    JobSet = Data.define(:name, :size, :jobs, :all) do
      def all? = all
    end
  end
end
