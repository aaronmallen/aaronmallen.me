# frozen_string_literal: true

module Links
  module Structs
    Link = Data.define(:kind, :id, :title, :day, :url)
  end
end
