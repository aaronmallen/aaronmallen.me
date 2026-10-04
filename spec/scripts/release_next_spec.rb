# frozen_string_literal: true

require "open3"
require "tmpdir"

RSpec.describe "mise run release:next", type: :script do
  let(:script) { Hanami.app.root.join("scripts/release/next").to_s }
  let(:repo) { Dir.mktmpdir }

  after { FileUtils.remove_entry(repo) }

  def git(*)
    author = ["-c", "user.name=Spec", "-c", "user.email=spec@example.com"]
    output, status = Open3.capture2e("git", *author, *, chdir: repo)
    raise output unless status.success?

    output
  end

  def next_version(*)
    output, status = Open3.capture2e(script, *, chdir: repo)
    raise output unless status.success?

    output.chomp
  end

  def tag(*names)
    git("init", "--quiet")
    git("commit", "--quiet", "--allow-empty", "--message", "Initial commit")
    names.each { git("tag", "--annotate", it, "--message", it) }
  end

  context "with the tags in #382" do
    before { tag(*Hanami.app.root.join("spec/fixtures/tags.txt").readlines(chomp: true)) }

    it "counts one past the highest release of the month" do
      expect(next_version("2026-10-03")).to eq("26.10.3")
    end

    it "starts a new month at 0" do
      expect(next_version("2026-11-01")).to eq("26.11.0")
    end

    it "drops the leading zero from the month" do
      expect(next_version("2026-09-30")).to eq("26.9.5")
    end

    it "ignores the old 1.x tags" do
      expect(next_version("2026-01-15")).to eq("26.1.0")
    end

    it "makes no tag" do
      expect { next_version("2026-10-03") }.not_to(change { git("tag", "--list") })
    end
  end

  it "counts past 9 by number, not by text" do
    tag(*(0..10).map { "26.12.#{it}" })

    expect(next_version("2026-12-31")).to eq("26.12.11")
  end

  it "names today's UTC month with no date given" do
    tag
    now = Time.now.utc

    expect(next_version).to eq("#{now.strftime('%y')}.#{now.month}.0")
  end

  it "refuses a date in another shape", :aggregate_failures do
    tag

    output, status = Open3.capture2e(script, "2026-1-1", chdir: repo)

    expect(status).not_to be_success
    expect(output).to include("YYYY-MM-DD")
  end
end
