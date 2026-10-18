# auto_register: false
# frozen_string_literal: true

module Agents
  module SessionWrite
    AUTHOR = %i[agent model session_id].freeze

    private

    def author(fields) = fields.slice(*AUTHOR)

    def touch(fields) = touch_session.call(fields[:session_id])
  end
end
