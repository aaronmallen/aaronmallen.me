# frozen_string_literal: true

RSpec.describe "Admin palette search", type: :request do
  def found = JSON.parse(last_response.body).fetch("hits")

  def hit(kind) = hits(kind).tap { expect(it.length).to eq(1) }.first

  def hits(kind) = found.select { it.fetch("kind") == kind }

  def search(text, headers = {})
    get("/admin/search/palette", { q: text }, { "HTTP_ACCEPT" => "application/json", **headers })
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "a phrase from a journal entry" do
      let(:day) { Date.new(2026, 10, 1) }
      let!(:entry) { create(:journal_entry, entry_date: day, body: "Walked the levee at dawn\nThe river ran high") }

      before { search("levee") }

      it "answers with JSON", :aggregate_failures do
        expect(last_response.status).to eq(200)
        expect(last_response.media_type).to eq("application/json")
      end

      it "lists the entry with its kind, title and where it lives" do
        expect(hit("journal")).to include(
          "kind" => "journal", "id" => entry.id, "title" => "Walked the levee at dawn",
          "href" => "/admin/journal?to=2026-10-01#day-2026-10-01",
        )
      end

      it "quotes the words around the match" do
        expect(hit("journal").fetch("match")).to include("levee")
      end

      it "keeps the answer out of every cache" do
        expect(last_response.headers["Cache-Control"]).to include("no-store")
      end
    end

    describe "a phrase several kinds hold" do
      before do
        create(:task, title: "Track the zeppelin")
        create(:post, :published, title: "Zeppelins", body: "A post")
        create(:message, subject: "Zeppelin sighting")
        search("zeppelin")
      end

      it "lists them in one list, each with its kind" do
        expect(found.map { it.fetch("kind") }).to contain_exactly("task", "post", "message")
      end
    end

    describe "more hits than it shows" do
      before do
        6.times { create(:task, title: "Call the plumber #{it}") }
        3.times { create(:message, subject: "Plumber quote #{it}") }
        search("plumber")
      end

      it "lists the top eight across every kind" do
        expect(found.length).to eq(8)
      end
    end

    describe "where each hit leads" do
      it "sends a task, closed or not, to its page" do
        task = create(:task, :done, title: "Renew the passport")
        search("passport")

        expect(hit("task").fetch("href")).to eq("/admin/tasks/#{task.id}")
      end

      it "sends a post to its editor" do
        post = create(:post, :draft, title: "Notes on kayaks")
        search("kayaks")

        expect(hit("post").fetch("href")).to eq("/admin/posts/#{post.id}/edit")
      end

      it "sends a social post to its editor on the social screen" do
        social_post = create(:social_post, :posted)
        create(:social_post_part, social_post_id: social_post.id, body: "Saw a heron today")
        search("heron")

        expect(hit("social").fetch("href")).to eq("/admin/social?edit=#{social_post.id}")
      end

      it "sends a commit to its page" do
        commit = create(:commit, repo: "aaronmallen/secret-lab", message: "Wire the thermostat relay")
        search("thermostat")

        expect(hit("commit").fetch("href")).to eq("/admin/commits/#{commit.id}")
      end

      it "sends a project to its editor" do
        project = create(:project, name: "airship", tagline: "Blimp tracker")
        search("blimp")

        expect(hit("project").fetch("href")).to eq("/admin/projects/#{project.id}/edit")
      end

      it "sends a work entry to the work list" do
        create(:work_entry, org: "Gondola Works", role: "Pilot")
        search("gondola")

        expect(hit("work").fetch("href")).to eq("/admin/projects?filter=work")
      end

      it "sends a person to their editor" do
        person = create(:person, name: "Ada Lovelace")
        search("lovelace")

        expect(hit("person").fetch("href")).to eq("/admin/people/#{person.id}/edit")
      end

      it "sends a message to the list that holds it" do
        create(:message, :read, subject: "Hello", body: "Loved your piece on sourdough")
        search("sourdough")

        expect(hit("message").fetch("href")).to eq("/admin/messages?status=read")
      end

      it "sends a decision to its page" do
        decision = create(:decision, title: "Pick a hangar", problem: "Where the airship sleeps")
        search("airship")

        expect(hit("decision").fetch("href")).to eq("/admin/decisions/#{decision.id}")
      end

      it "sends a webmention to the list that holds it" do
        create(:webmention, :approved, author_name: "Grace Hopper")
        search("hopper")

        expect(hit("webmention").fetch("href")).to eq("/admin/webmentions?status=approved")
      end
    end

    describe "a blank query" do
      before do
        create(:task, title: "Call the plumber")
        search("   ")
      end

      it "finds nothing" do
        expect(found).to be_empty
      end
    end
  end

  describe "signed out" do
    before do
      create(:task, title: "Email the accountant")
      search("accountant")
    end

    it "answers 401" do
      expect(last_response.status).to eq(401)
    end

    it "lists nothing" do
      expect(last_response.body).not_to include("Email the accountant")
    end

    it "keeps the route out of where sign-in sends me" do
      expect(last_request.env["rack.session"]["return_to"]).to be_nil
    end
  end

  describe "with an API token and no session" do
    before do
      create(:task, title: "Email the accountant")
      token = API::Slice["operations.mint_token"].call(name: "Terminal").value!.fetch(:token)
      search("accountant", "HTTP_AUTHORIZATION" => "Bearer #{token}")
    end

    it "answers 401" do
      expect(last_response.status).to eq(401)
    end
  end
end
