# frozen_string_literal: true

module Spec
  class IssueClient
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

      Blog::CursorPaging::Listing.new(items: assigned, cut_short: false)
    end

    def configured? = configured

    def issues(urls)
      @asked = urls
      []
    end
  end
end
