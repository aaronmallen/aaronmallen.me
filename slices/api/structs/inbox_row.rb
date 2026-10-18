# frozen_string_literal: true

module API
  module Structs
    InboxRow = Data.define(:kind, :at, :record)
    InboxRow::KINDS = { tasks: "task", messages: "message", webmentions: "webmention" }.freeze
  end
end
