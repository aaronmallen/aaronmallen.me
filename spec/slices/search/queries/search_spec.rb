# frozen_string_literal: true

RSpec.describe Search::Queries::Search do
  let(:db) { Search::Slice["db.rom"].gateways[:default].connection }
  let(:page) { Blog::Page.new(number: 1, size: 20) }
  let(:today) { Blog::TimeZone.today }

  def found(text, **) = search(text, **).rows

  def hit(text, **) = found(text, **).tap { expect(it.length).to eq(1) }.first

  def search(text, **) = Search::Slice["queries.search"].call(text:, page:, **)

  describe "a record the admin keeps private or closed" do
    it "finds a journal entry" do
      entry = create(:journal_entry, body: "Walked the levee at dawn")

      expect(hit("levee")).to have_attributes(kind: "journal", source_id: entry.id)
    end

    it "finds a closed task" do
      task = create(:task, :done, title: "Renew the passport")

      expect(hit("passport")).to have_attributes(kind: "task", source_id: task.id, status: "done")
    end

    it "finds a canceled task" do
      task = create(:task, :canceled, title: "Repaint the porch")

      expect(hit("porch")).to have_attributes(kind: "task", source_id: task.id)
    end

    it "finds a commit from a private repo" do
      commit = create(:commit, repo: "aaronmallen/secret-lab", message: "Wire the thermostat relay")

      expect(hit("thermostat")).to have_attributes(kind: "commit", source_id: commit.id)
    end

    it "finds a read message" do
      message = create(:message, :read, subject: "Hello", body: "Loved your piece on sourdough")

      expect(hit("sourdough")).to have_attributes(kind: "message", source_id: message.id, status: "read")
    end

    it "finds a draft post" do
      post = create(:post, :draft, title: "Notes on kayaks", body: "Half done")

      expect(hit("kayaks")).to have_attributes(kind: "post", source_id: post.id, status: "draft")
    end
  end

  describe "every kind" do
    before do
      create(:task, title: "Open task", note: "about zeppelins")
      create(:post, :published, title: "Zeppelins", body: "A post")
      create(:social_post_part, social_post_id: create(:social_post, :posted).id, body: "Saw a zeppelin")
      create(:journal_entry, body: "Dreamt of zeppelins")
      create(:commit, message: "Draw the zeppelin")
      create(:project, name: "airship", tagline: "Zeppelin tracker")
      create(:work_entry, org: "Zeppelin Works", role: "Pilot")
      create(:person, name: "Zeppelin Fan")
      create(:message, subject: "Zeppelins", body: "Hi there")
      create(:webmention, excerpt: "Nice zeppelin")
    end

    it "finds one of each" do
      expect(found("zeppelin").map(&:kind)).to match_array(Blog::Types::SearchKind.values)
    end
  end

  describe "what a result carries" do
    describe "a long post" do
      let!(:post) { create(:post, :published, title: "Bread", body: "#{'flour ' * 200}crumb #{'salt ' * 200}") }

      it "carries its title" do
        expect(hit("crumb").title).to eq("Bread")
      end

      it "carries a short match around the phrase" do
        expect(hit("crumb").match).to include("crumb")
      end

      it "carries the day it went out" do
        expect(hit("crumb").day).to eq(Blog::TimeZone.local(post.published_at).to_date)
      end
    end

    it "keeps the match short" do
      create(:journal_entry, body: "#{'rain ' * 100}garden")

      expect(hit("garden").match.split.length).to be <= 24
    end

    it "leaves markup out of the match" do
      create(:journal_entry, body: "Fed the ducks")

      expect(hit("ducks").match).to eq("Fed the ducks")
    end

    it "carries the slug of a post" do
      create(:post, :published, title: "Bread", slug: "bread")

      expect(hit("bread").slug).to eq("bread")
    end

    it "carries the repo and sha of a commit" do
      commit = create(:commit, message: "Tune the cache")

      expect(hit("cache")).to have_attributes(repo: commit.repo, sha: commit.sha)
    end

    it "carries the url of a project" do
      project = create(:project, name: "lantern")

      expect(hit("lantern").url).to eq(project.url)
    end

    it "carries the source url of a webmention" do
      mention = create(:webmention, excerpt: "A fine walrus")

      expect(hit("walrus").url).to eq(mention.source_url)
    end

    it "takes the day of a journal entry from its date" do
      create(:journal_entry, body: "Bought a canoe", entry_date: today - 30)

      expect(hit("canoe").day).to eq(today - 30)
    end

    it "takes the day of an open task from when it was made" do
      create(:task, title: "Find the ladder")

      expect(hit("ladder").day).to eq(today)
    end

    it "gives the first line of a commit as its title" do
      create(:commit, message: "Fix the gutter\n\nIt leaked")

      expect(hit("leaked").title).to eq("Fix the gutter")
    end
  end

  describe "a social post with several parts" do
    let(:social_post) { create(:social_post, :posted) }

    before do
      create(:social_post_part, social_post_id: social_post.id, body: "Otters are out")
      create(:social_post_part, social_post_id: social_post.id, body: "Otters otters otters")
    end

    it "comes back once" do
      expect(found("otters").map(&:source_id)).to eq([social_post.id])
    end

    it "shows the part that matches best" do
      expect(hit("otters").title).to eq("Otters otters otters")
    end
  end

  describe "the order" do
    it "ranks a title match above a match in the text" do
      create(:task, title: "Errands", note: "Pick up the mangoes")
      create(:task, title: "Mangoes")

      expect(found("mangoes").map(&:title)).to eq(%w[Mangoes Errands])
    end

    it "puts the newer one first on a tie" do
      create(:journal_entry, body: "Lemons", entry_date: today - 2)
      create(:journal_entry, body: "Lemons", entry_date: today - 1)

      expect(found("lemons").map(&:day)).to eq([today - 1, today - 2])
    end
  end

  describe "the phrase" do
    it "matches a word by its stem" do
      create(:journal_entry, body: "Running at noon")

      expect(found("runs").length).to eq(1)
    end

    it "leaves out a word the phrase rules out" do
      create(:journal_entry, body: "Plums and figs")
      create(:journal_entry, body: "Plums alone")

      expect(found("plums -figs").map(&:title)).to eq(["Plums alone"])
    end

    it "finds nothing for a blank phrase" do
      create(:journal_entry, body: "Anything")

      expect(found("  ")).to be_empty
    end

    it "finds nothing for a phrase of stop words" do
      create(:journal_entry, body: "The and of")

      expect(found("the")).to be_empty
    end
  end

  describe "narrowing" do
    before do
      create(:task, title: "Walnut tart")
      create(:journal_entry, body: "Baked a walnut tart")
      create(:message, subject: "Walnut", body: "Recipe please")
    end

    it "keeps only the kinds asked for" do
      expect(found("walnut", kinds: %w[task message]).map(&:kind)).to match_array(%w[task message])
    end

    it "finds nothing when no kind is asked for" do
      expect(found("walnut", kinds: [])).to be_empty
    end
  end

  describe "the cap per kind" do
    before do
      4.times { create(:task, title: "Juggle #{it}") }
      3.times { create(:journal_entry, body: "Juggled #{it}") }
      create(:commit, message: "Juggling")
    end

    it "keeps no more than the cap of each kind" do
      expect(found("juggle", per_kind: 2).map(&:kind).tally).to eq("task" => 2, "journal" => 2, "commit" => 1)
    end
  end

  describe "paging" do
    let(:page) { Blog::Page.new(number:, size: 2) }

    before { 5.times { create(:journal_entry, body: "Heron #{it}", entry_date: today - it) } }

    context "with the first page" do
      let(:number) { 1 }

      it "holds a page of results and says more remain" do
        expect(search("heron")).to have_attributes(rows: have_attributes(length: 2), more: true)
      end
    end

    context "with the last page" do
      let(:number) { 3 }

      it "holds the rest and says none remain" do
        expect(search("heron")).to have_attributes(rows: [have_attributes(day: today - 4)], more: false)
      end
    end
  end

  describe "the query plan" do
    let(:indexes) do
      %w[
        tasks posts social_post_parts journal_entries commits projects work_entries people messages webmentions
      ].map { "#{it}_search_vector_index" }
    end

    def plan
      db.transaction do
        db.run("SET LOCAL enable_seqscan = off")
        db["EXPLAIN #{sql}"].map(:"QUERY PLAN").join("\n")
      end
    end

    def sql
      relation = Search::Slice["relations.search_documents"]

      relation.hits("x", kinds: Blog::Types::SearchKind.values, per_kind: 5, page:).sql
    end

    it "reads each table's index" do
      expect(plan).to include(*indexes)
    end
  end
end
