# frozen_string_literal: true

module MCP
  module Tools
    class ListSocialPosts < Base
      description "List social posts, newest first, sent and unsent alike: each with its " \
                  "status, its parts in order, each part's length and limit on each network it targets and, " \
                  "per network, how delivery stands (waiting, sending, retrying, sent or failed) with the link, " \
                  "error and engagement counts. " \
                  "A post falls on the day it went out or is set to go out, and a draft on the day it was made. " \
                  "Give queue to keep only the queued, posted or draft posts, as the admin's social screen splits " \
                  "them. counts gives how many posts in the range sit in each queue, whatever queue asks for. " \
                  "Give from, to or both as YYYY-MM-DD to keep only those days; both days sit inside the range. " \
                  "Leave both out to list every social post. #{Blog::Paging::USAGE}"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
