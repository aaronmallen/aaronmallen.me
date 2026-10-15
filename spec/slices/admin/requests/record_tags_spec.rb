# frozen_string_literal: true

RSpec.describe "Admin record tags", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:tags) { Tags::Slice["relations.tags"] }

  shared_examples "a tag route" do |path:, list:, scope:|
    def send_tag(record, verb, tag, **)
      suffix = verb == :untag ? "/tags/delete" : "/tags"
      post "#{base}/#{record.id}#{suffix}", { _csrf_token: admin_csrf_token, tag:, ** }
    end

    let(:base) { "/admin/#{path}" }
    let(:other_scope) { scope == "public" ? "private" : "public" }

    before { sign_in_to_admin }

    describe "tag" do
      before { send_tag(record, :tag, " Hanami ") }

      it "adds the tag and keeps the others" do
        expect(tag_names(record)).to eq(%w[hanami ruby])
      end

      it "makes the tag in the #{scope} scope" do
        expect(tags.where(name: "hanami").pluck(:scope)).to eq([scope])
      end

      it "goes back to the list with a toast", :aggregate_failures do
        expect(last_response.headers["location"]).to eq(list)
        follow_redirect!
        expect(toast).to eq("Tagged hanami")
      end
    end

    it "takes a #{scope} tag even when the name is taken in the other scope", :aggregate_failures do
      create(:tag, name: "elixir", scope: other_scope)
      send_tag(record, :tag, "elixir")

      expect(tag_names(record)).to eq(%w[elixir ruby])
      expect(tags.where(name: "elixir").pluck(:scope)).to contain_exactly("public", "private")
    end

    describe "untag" do
      before { send_tag(record, :untag, "ruby") }

      it "takes the tag off" do
        expect(tag_names(record)).to be_empty
      end

      it "says so" do
        follow_redirect!

        expect(toast).to eq("Took ruby off")
      end
    end

    it "goes back where the menu asked" do
      send_tag(record, :tag, "hanami", return_to: "/admin/tags/hanami")

      expect(last_response.headers["location"]).to eq("/admin/tags/hanami")
    end

    it "ignores a return path off the admin" do
      send_tag(record, :tag, "hanami", return_to: "https://example.com/")

      expect(last_response.headers["location"]).to eq(list)
    end

    it "asks for a tag when none came", :aggregate_failures do
      send_tag(record, :tag, " ")
      follow_redirect!

      expect(toast).to eq("Type a tag first")
      expect(tag_names(record)).to eq(%w[ruby])
    end

    it "refuses a tag that is not a slug", :aggregate_failures do
      send_tag(record, :tag, "not a tag!")
      follow_redirect!

      expect(toast).to eq("Nothing changed · a tag takes lowercase letters, numbers and dashes")
      expect(tag_names(record)).to eq(%w[ruby])
    end

    it "answers 404 for a record that is gone" do
      post "#{base}/0/tags", { _csrf_token: admin_csrf_token, tag: "ruby" }

      expect(last_response.status).to eq(404)
    end
  end

  describe "a journal entry" do
    let(:repo) { Record::Slice["repos.journal_entry_queries"] }
    let(:record) { create(:journal_entry).tap { Record::Slice["repos.journal_entry_mutations"].replace_tags(it.id, ["ruby"]) } }

    def tag_names(entry) = repo.by_id(entry.id).tags.map(&:name).sort

    it_behaves_like "a tag route", path: "journal", list: "/admin/journal", scope: "private"
  end

  describe "a decision" do
    let(:repo) { Decisions::Slice["repos.decision_queries"] }
    let(:record) { create(:decision).tap { Decisions::Slice["repos.decision_mutations"].replace_tags(it.id, ["ruby"]) } }

    def tag_names(decision) = repo.by_id(decision.id).tags.map(&:name).sort

    it_behaves_like "a tag route", path: "decisions", list: "/admin/decisions", scope: "private"
  end

  describe "a project" do
    let(:repo) { Projects::Slice["repos.project_queries"] }
    let(:record) { create(:project).tap { Projects::Slice["repos.project_mutations"].replace_tags(it.id, ["ruby"]) } }

    def tag_names(project) = repo.by_id(project.id).tags.map(&:name).sort

    it_behaves_like "a tag route", path: "projects", list: "/admin/projects", scope: "public"
  end
end
