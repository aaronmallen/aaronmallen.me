# frozen_string_literal: true

save_tag = Tags::Slice["operations.save_tag"]
all_tags = Tags::Slice["queries.all"]

{
  "public" => %w[hanami ruby postgres tooling writing],
  "private" => %w[chores errands health home reading],
}.each do |scope, names|
  held = all_tags.call(scope:).map(&:name)

  (names - held).each { Seeds.unwrap(save_tag.call({ name: it }, scope:)) }
end
