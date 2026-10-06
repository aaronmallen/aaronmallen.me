# frozen_string_literal: true

module Search
  module Structs
    Hit = Data.define(:kind, :source_id, :title, :match, :day, :status)
  end
end
