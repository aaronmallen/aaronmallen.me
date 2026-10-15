# frozen_string_literal: true

module Search
  module Structs
    PublicHit = Data.define(:kind, :source_id, :title, :match, :day, :status, :slug, :project, :number)
  end
end
