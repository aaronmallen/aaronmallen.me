# frozen_string_literal: true

require "open3"
require "tmpdir"

RSpec.describe "mise run dev:prune-workspaces", type: :script do
  let(:worktrees) { Dir.mktmpdir }
  let(:env) { { "DATABASE_NAME" => "blog_prune_spec", "WORKTREES_DIR" => worktrees } }
  let(:kept) { %w[blog_prune_spec_test blog_prune_spec_test_w2 blog_prune_spec_test_7 blog_prune_spec_test_7_w2] }
  let(:gone) { %w[blog_prune_spec_test_8 blog_prune_spec_test_8_w2] }

  before do
    FileUtils.mkdir(File.join(worktrees, "ws7"))
    psql(*(kept + gone).flat_map { ["drop database if exists #{it}", "create database #{it}"] })
  end

  after do
    psql(*(kept + gone).map { "drop database if exists #{it}" })
    FileUtils.remove_entry(worktrees)
  end

  def databases = psql("select datname from pg_database where datname like 'blog_prune_spec%'").split

  def psql(*statements)
    command = ["scripts/util/psql", "-d", "postgres", "-At", *statements.flat_map { ["-c", it] }]
    output, status = Open3.capture2e(env, *command, chdir: Hanami.app.root)
    raise output unless status.success?

    output
  end

  it "drops and lists the test databases of workspaces with no directory", :aggregate_failures do
    output, status = Open3.capture2e(env, "scripts/dev/prune-workspaces", chdir: Hanami.app.root)

    expect(status).to be_success
    expect(output.split).to match_array(gone)
    expect(databases).to match_array(kept)
  end
end
