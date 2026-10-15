# auto_register: false
# frozen_string_literal: true

module API
  module Endpoints
    module MailThreads
      BULK = Helpers::Schema.bulk("mail threads")
      COMPLAINTS = { tag: Helpers::Tags::COMPLAINTS }.freeze
      TAG = Helpers::Tags.schema("private")

      THREAD = Serializers::MailThread::SCHEMA
      HEAD = THREAD.merge(
        properties: THREAD.fetch(:properties).except(:body, :reply_to),
        required: THREAD.fetch(:required) - %w[body reply_to],
      ).freeze
      SUMMARY = THREAD.merge(
        properties: THREAD.fetch(:properties).except(:body),
        required: THREAD.fetch(:required) - %w[body],
      ).freeze
    end
  end
end
