# frozen_string_literal: true

require "open3"

RSpec.describe "Blog/UnusedDeps", type: :script do
  def lint(*names)
    source = <<~RUBY
      module Demo
        class Operation
          include Deps[#{names.map { |name| "#{name}: \"repos.#{name}\"" }.join(', ')}]
        end
      end
    RUBY
    output, status = Open3.capture2e(
      "bundle", "exec", "rubocop", "--config", ".config/rubocop.yml", "--only", "Blog/UnusedDeps",
      "--stdin", "slices/demo/operation.rb",
      chdir: Hanami.app.root.to_s, stdin_data: source,
    )
    [status.success?, output]
  end

  it "fails a dep outside the list that the class never reads" do
    expect(lint("contract", "mailer")).to match([false, a_string_including("mailer from Deps")])
  end
end
