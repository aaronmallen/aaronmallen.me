# auto_register: false
# frozen_string_literal: true

module Agents
  module SessionWrite
    def self.included(operation) = operation.include(Deps[touch_session: "operations.touch_session"])

    private

    def validate(params) = super.bind { |fields| touch_session.call(fields[:session_id]).fmap { fields } }
  end
end
