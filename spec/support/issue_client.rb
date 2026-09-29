# frozen_string_literal: true

module Spec
  class IssueClient
    Listing = Data.define(:items)

    attr_accessor :configured, :failure
    attr_reader :asked, :assigned

    def initialize
      @asked = nil
      @assigned = []
      @configured = true
      @failure = nil
    end

    def assigned_issues
      raise failure if failure

      Listing.new(items: assigned)
    end

    def configured? = configured

    def issues(urls)
      @asked = urls
      []
    end
  end
end
