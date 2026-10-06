# frozen_string_literal: true

module MCP
  module Tools
    class ReadTimeReport < Base
      description "Read the time worked in a range the way the admin's time screen shows it, summed by tag, " \
                  "project or day, tag when left out. Give from and to as YYYY-MM-DD; both days count. Each group " \
                  "gives its key, its name, its seconds, whether its time also counts in another group, and the " \
                  "tasks behind it with their seconds. A task in two projects or under two tags counts in both, so " \
                  "the groups can add up to more than seconds, the range's total. Tasks with no project or tag sit " \
                  "last, with a null key and name"
      endpoint scope: OAuth::Scope::READ
    end
  end
end
