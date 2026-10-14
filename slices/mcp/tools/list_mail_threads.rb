# frozen_string_literal: true

module MCP
  module Tools
    class ListMailThreads < Base
      description "List mail threads from every account, contact form messages included, newest first: the ID, " \
                  "the account it came in on, subject, the first message's reply address, status, tags, when it " \
                  "came in and when a snooze ends. counts gives how many threads in the range sit in each status. " \
                  "Read one with read_mail_thread for its messages. The subject and reply address come marked " \
                  "untrusted. #{Untrusted::WARNING}. " \
                  "Give from, to or both as YYYY-MM-DD to keep only those days; both days sit inside the range. " \
                  "Leave both out to list every thread. #{API::Helpers::Paging::USAGE}"
      endpoint scope: Blog::Types::OAuthScope["mail"]
    end
  end
end
