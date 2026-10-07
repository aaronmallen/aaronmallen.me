# frozen_string_literal: true

save_tag = Tags::Slice["operations.save_tag"]
tag_queries = Tags::Slice["repos.tag_queries"]

{
  "public" => %w[hanami ruby postgres tooling writing],
  "private" => %w[chores errands health home reading],
}.each do |scope, names|
  held = tag_queries.all_in(scope).map(&:name)

  (names - held).each { Seeds.unwrap(save_tag.call({ name: it }, scope:)) }
end
