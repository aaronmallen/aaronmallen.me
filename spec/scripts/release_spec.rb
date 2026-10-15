# frozen_string_literal: true

require "open3"
require "tmpdir"

RSpec.describe "mise run release", type: :script do
  let(:root) { Dir.mktmpdir }
  let(:env) do
    {
      "GIT_CONFIG_GLOBAL" => File::NULL,
      "GIT_CONFIG_NOSYSTEM" => "1",
      "JJ_CONFIG" => File.join(root, "jj.toml"),
      "JJ_EMAIL" => "spec@example.com",
      "JJ_USER" => "Spec",
      "PATH" => "#{bin}:#{ENV.fetch('PATH')}",
    }
  end

  before do
    FileUtils.mkdir_p([repo, bin])
    File.write(File.join(bin, "gh"), "#!/bin/sh\ncat \"$(dirname \"$0\")/ci\"\n")
    File.chmod(0o755, File.join(bin, "gh"))
    ci("passed")
  end

  after { FileUtils.remove_entry(root) }

  def bin = File.join(root, "bin")

  def ci(state)
    path = File.join(bin, "ci")
    state ? File.write(path, state) : FileUtils.rm_f(path)
  end

  def commit(message, file: nil)
    File.write(File.join(repo, file), message) if file
    git("add", "--all")
    git("commit", "--quiet", "--allow-empty", "--message", message)
    git("rev-parse", "HEAD").chomp
  end

  def git(*) = run("git", "-c", "user.name=Spec", "-c", "user.email=spec@example.com", "-c", "tag.gpgSign=false", *)

  def init_git
    git("init", "--quiet")
    git("config", "tag.gpgSign", "true")
  end

  def next_version(*)
    output, status = release("--dry-run", *)
    raise output unless status.success?

    output.lines.first.chomp
  end

  def release(*) = Open3.capture2e(env, Hanami.app.root.join("scripts/release").to_s, *, chdir: repo)

  def repo = File.join(root, "repo")

  def run(*command)
    output, status = Open3.capture2e(env, *command, chdir: repo)
    raise output unless status.success?

    output
  end

  def tag(*names)
    init_git
    commit("Initial commit", file: "a.txt")
    names.each { git("tag", "--annotate", it, "--message", it) }
  end

  def write_changelog(*versions, unreleased: nil)
    sections = versions.map { "## [#{it}] - 2026-10-14\n\n### Fixed\n\n- Something.\n" }
    File.write(File.join(repo, "CHANGELOG.md"), <<~MARKDOWN)
      # Changelog

      ## [Unreleased]
      #{unreleased}
      #{sections.join("\n")}
    MARKDOWN
  end

  describe "naming" do
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

      output, status = release("2026-1-1")

      expect(status).not_to be_success
      expect(output).to include("YYYY-MM-DD")
    end
  end

  context "with git" do
    let!(:target) do
      init_git
      write_changelog("26.10.0")
      commit("Add the changelog", file: "a.txt")
    end

    before do
      commit("Empty")
      commit("Also empty")
    end

    context "when it tags" do
      let!(:result) do
        remote = File.join(root, "remote.git")
        run("git", "init", "--quiet", "--bare", remote)
        git("remote", "add", "origin", remote)
        release("2026-10-14")
      end

      it "makes an annotated tag on the newest commit that is not empty", :aggregate_failures do
        expect(result.last).to be_success
        expect(git("cat-file", "-t", "26.10.0").chomp).to eq("tag")
        expect(git("rev-parse", "26.10.0^{commit}").chomp).to eq(target)
      end

      it "writes the bare version as the message and does not sign it", :aggregate_failures do
        expect(git("tag", "--list", "--format=%(contents)", "26.10.0").strip).to eq("26.10.0")
        expect(git("cat-file", "-p", "26.10.0")).not_to include("SIGNATURE")
      end

      it "prints the push command and does not push", :aggregate_failures do
        expect(result.first).to include("git push origin 26.10.0")
        expect(run("git", "ls-remote", "--tags", "origin")).to be_empty
      end
    end

    it "prints the version, the target and its CI state on a dry run and makes no tag", :aggregate_failures do
      ci("running")
      output, status = release("--dry-run", "2026-10-14")

      expect(status).to be_success
      expect(output.lines.map(&:chomp)).to eq(["26.10.0", target, "CI running"])
      expect(git("tag", "--list")).to be_empty
    end

    it "reports an unknown CI state on a dry run when gh fails" do
      ci(nil)
      output, = release("--dry-run", "2026-10-14")

      expect(output.lines.last.chomp).to eq("CI unknown")
    end

    shared_examples "a refusal" do |reason|
      it "exits non-zero, says why and makes no new tag", :aggregate_failures do
        tags = git("tag", "--list")
        output, status = release("2026-10-14")

        expect(status).not_to be_success
        expect(output).to include(reason)
        expect(git("tag", "--list")).to eq(tags)
      end
    end

    context "when the target already carries a version tag" do
      before { git("tag", "--annotate", "26.9.4", "--message", "26.9.4", target) }

      it_behaves_like "a refusal", "already carries 26.9.4"
    end

    context "when [Unreleased] still has entries" do
      before do
        write_changelog("26.10.0", unreleased: "\n### Added\n\n- Something new.\n")
        commit("Add an entry")
      end

      it_behaves_like "a refusal", "entries under [Unreleased]"
    end

    context "when the changelog has no section for the version" do
      before do
        write_changelog("26.9.0")
        commit("Drop the section")
      end

      it_behaves_like "a refusal", "no section for 26.10.0"
    end

    {
      "running" => "CI is still running",
      "failed" => "CI did not pass",
      "missing" => "CI has not run",
      nil => "Could not read the CI state",
    }.each do |state, reason|
      context "when CI is #{state || 'unreadable'}" do
        before { ci(state) }

        it_behaves_like "a refusal", reason
      end
    end

    context "with --skip-ci" do
      before { ci("failed") }

      it "tags anyway and says it skipped the check", :aggregate_failures do
        output, status = release("--skip-ci", "2026-10-14")

        expect(status).to be_success
        expect(output).to include("Skipped the CI check on #{target}.")
        expect(git("rev-parse", "26.10.0^{commit}").chomp).to eq(target)
      end
    end
  end

  context "with jj", skip: ("jj is not installed" unless system("command -v jj >/dev/null 2>&1")) do
    let!(:target) do
      run("jj", "git", "init", "--colocate", "--quiet")
      write_changelog("26.10.0")
      run("jj", "commit", "--quiet", "--message", "Add the changelog")
      run("jj", "commit", "--quiet", "--message", "Empty")
      run("jj", "log", "--no-graph", "-r", "@--", "-T", "commit_id")
    end

    it "skips the empty commits on top", :aggregate_failures do
      _, status = release("2026-10-14")

      expect(status).to be_success
      expect(git("cat-file", "-t", "26.10.0").chomp).to eq("tag")
      expect(git("rev-parse", "26.10.0^{commit}").chomp).to eq(target)
    end

    it "names the same target on a dry run" do
      output, = release("--dry-run", "2026-10-14")

      expect(output.lines.map(&:chomp)).to eq(["26.10.0", target, "CI passed"])
    end
  end
end
