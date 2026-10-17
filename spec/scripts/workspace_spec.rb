# frozen_string_literal: true

require "open3"

RSpec.describe "mise run dev:create-workspace and dev:remove-workspace", type: :script do
  def script(name, *) = Open3.capture2e(Hanami.app.root.join("scripts/dev", name).to_s, *, chdir: Hanami.app.root)

  %w[create-workspace remove-workspace].product(["", "12a"]).each do |name, id|
    it "#{name} refuses #{id.inspect} as an id", :aggregate_failures do
      output, status = script(name, id)

      expect(status.exitstatus).to eq(1)
      expect(output).to eq("id must be a number\n")
    end
  end

  it "finds each workspace under WORKTREES_DIR when it is set" do
    output, = Open3.capture2e({ "WORKTREES_DIR" => "/elsewhere" }, "scripts/util/workspace", "7",
                              chdir: Hanami.app.root)

    expect(output).to eq("/elsewhere/ws7\n")
  end
end
