# frozen_string_literal: true

RSpec.describe Search::Repos::PublicSearchQueries do
  subject(:repo) { described_class.new }

  let(:board) { create(:project, name: "Board", tagline: "Plans", board_published: true) }

  def counts(text = "zeppelin", **) = repo.counts(text:, **)

  def hits(text = "zeppelin", **)
    repo.search(text:, page: Blog::Structs::Page.new(number: 1, size: 50), **).rows
  end

  def titles(...) = hits(...).map(&:title)

  describe "what a visitor can find" do
    before do
      create(:post, :published, title: "Zeppelin post", slug: "zeppelin-post", body: "A post")
      create(:project, name: "Zeppelin", tagline: "A live one")
      create(:project, :archived, name: "Old zeppelin", tagline: "An old one")
      create(:task, title: "Zeppelin task", project_id: board.id)
    end

    it "finds published posts, public projects and tasks on published boards" do
      expect(titles).to contain_exactly("Zeppelin post", "Zeppelin", "Old zeppelin", "Zeppelin task")
    end

    it "carries what a link needs", :aggregate_failures do
      found = hits.to_h { [it.kind, it] }

      expect(found["post"]).to have_attributes(slug: "zeppelin-post", status: nil, match: include("Zeppelin"))
      expect(found["project"].status).to eq("active")
      expect(found["task"]).to have_attributes(project: "Board", number: be_positive, status: "open")
    end

    it "counts each kind as many times as it hits" do
      expect(counts).to eq("post" => 1, "project" => 2, "task" => 1)
    end

    it "narrows hits and counts to the kinds asked for", :aggregate_failures do
      expect(titles(kinds: %w[project])).to contain_exactly("Zeppelin", "Old zeppelin")
      expect(counts(kinds: %w[project])).to eq("project" => 2)
    end
  end

  describe "what a visitor never finds" do
    before do
      create(:post, :draft, title: "Draft zeppelin")
      create(:post, :scheduled, title: "Scheduled zeppelin")
      create(:project, :private, name: "Hush", tagline: "A zeppelin secret", board_published: true)
      create(:project, :private, :archived, name: "Gone", tagline: "An old zeppelin secret")
      create(:task, title: "Unpublished zeppelin", project_id: create(:project, name: "Plain").id)
      create(:task, title: "Hidden zeppelin", project_id: create(:project, :private, board_published: true).id)
      create(:task, title: "Loose zeppelin")
    end

    it "leaves private records out of hits and counts", :aggregate_failures do
      expect(hits).to be_empty
      expect(counts).to be_empty
    end
  end

  describe "the kinds the site never shows" do
    before do
      create(:journal_entry, body: "A zeppelin day")
      create(:message, subject: "Zeppelin", body: "A zeppelin note")
      create(:commit, message: "Add the zeppelin")
      create(:person, name: "Zeppelin Fan")
      create(:webmention, excerpt: "A zeppelin mention")
      create(:social_post_part, social_post_id: create(:social_post, :draft).id, body: "A zeppelin toot")
      create(:decision, title: "Zeppelin or not")
      create(:pull_request, title: "Ship the zeppelin")
      create(:work_entry, org: "Zeppelin Inc")
    end

    it "leaves them out of hits and counts", :aggregate_failures do
      expect(hits).to be_empty
      expect(counts).to be_empty
    end
  end

  describe "tags" do
    before do
      create(:post, :published, title: "Tagged post", body: "A post", tags: %w[airships])
      create(:project, name: "Tagged project", tagline: "A project", tags: %w[airships])
      create(:task, title: "Tagged task", project_id: board.id, tags: %w[airships])
    end

    it "matches a public tag on posts and projects, never a task's tag" do
      expect(titles("airships")).to contain_exactly("Tagged post", "Tagged project")
    end

    it "lists a record its text and tag both match once, excerpted from its text" do
      create(:post, :published, title: "Airships aloft", body: "Up we go", tags: %w[airships])

      aloft = hits("airships").select { it.title == "Airships aloft" }

      expect(aloft.map(&:excerpt)).to eq([[["", false], ["Airships", true], [" aloft\n\nUp we go", false]]])
    end
  end

  describe "a quoted phrase" do
    before do
      create(:post, :published, title: "Red zeppelin", body: "It flies")
      create(:post, :published, title: "Zeppelin", body: "It is red")
    end

    it "matches only that phrase", :aggregate_failures do
      expect(titles('"red zeppelin"')).to eq(["Red zeppelin"])
      expect(counts('"red zeppelin"')).to eq("post" => 1)
    end
  end

  describe "a blank phrase" do
    it "finds nothing", :aggregate_failures do
      expect(hits(" ")).to be_empty
      expect(counts(" ")).to be_empty
    end
  end
end
