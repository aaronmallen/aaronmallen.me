# frozen_string_literal: true

module API
  module Structs
    InboxRow = Data.define(:kind, :at, :record)
  end
end
