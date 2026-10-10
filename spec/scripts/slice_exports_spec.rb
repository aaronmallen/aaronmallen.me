# frozen_string_literal: true

require "open3"

RSpec.describe "Hanami/SliceExports", type: :script do
  def lint(*keys)
    source = <<~RUBY
      module Demo
        class Slice < Hanami::Slice
          export %w[#{keys.join(' ')}]
        end
      end
    RUBY
    output, status = Open3.capture2e(
      "bundle", "exec", "rubocop", "--config", ".config/rubocop.yml", "--only", "Hanami/SliceExports",
      "--stdin", "slices/demo/config/slice.rb",
      chdir: Hanami.app.root.to_s, stdin_data: source,
    )
    [status.success?, output]
  end

  it "passes read repos and operations" do
    expect(lint("repos.queries", "repos.post_queries", "operations.save_post").first).to be(true)
  end

  it "fails on each forbidden key" do
    keys = %w[repos.mutations repos.post_mutations repos.post_repo queries.by_id relations.posts]
    offenses = a_string_including(*keys.map { |key| "#{key} matches ForbiddenExports" })

    expect(lint("operations.save_post", *keys)).to match([false, offenses])
  end
end
