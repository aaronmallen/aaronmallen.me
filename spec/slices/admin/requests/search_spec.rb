# frozen_string_literal: true

RSpec.describe "Admin search", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }

  def kinds = page.all(".search-kind").map { [it.text, it["aria-current"]] }

  def says(key, **) = i18n.t(["ui.views.search.index", key].join("."), **)

  def titles = page.all(".li-title").map(&:text)

  def titles_on(number)
    get "/admin/search", q: "plumber", kind: "task", page: number
    titles
  end

  describe "signed in" do
    before { sign_in_to_admin }

    describe "a phrase several kinds hold" do
      before do
        create(:task, :done, title: "Track the zeppelin")
        create(:post, :published, title: "Zeppelins", body: "A post")
        create(:message, :read, subject: "Zeppelin sighting")
        create(:task, title: "Call the plumber")
        get "/admin/search", q: "zeppelin"
      end

      it "lists every match and nothing else" do
        expect(titles).to contain_exactly("Track the zeppelin", "Zeppelins", "Zeppelin sighting")
      end

      it "groups the matches by kind", :aggregate_failures do
        expect(page.find(".card", text: "Tasks")).to have_css(".li-title", text: "Track the zeppelin")
        expect(page.find(".card", text: "Messages")).to have_css(".li-title", text: "Zeppelin sighting")
      end

      it "counts the matches in the sub-line" do
        expect(page).to have_css(".page-head-sub", exact_text: "3 results for “zeppelin”.")
      end

      it "keeps the query in the box" do
        expect(page).to have_field("q", with: "zeppelin")
      end

      it "offers every kind that matched, with its count, all of them chosen" do
        expect(kinds).to eq([["All kinds 3", "page"], ["Tasks 1", nil], ["Posts 1", nil], ["Messages 1", nil]])
      end

      it "links each kind with the query kept" do
        expect(page).to have_link("Messages 1", href: "/admin/search?q=zeppelin&kind=message")
      end
    end

    describe "a task label" do
      let(:podcast) { create(:project, name: "Podcast", tagline: "Talk", repo: "me/podcast", url: "https://podcast.test") }

      def in_project(title) = create(:task, project_id: podcast.id, title:)

      def labels = page.all(".card .li").map { it.first(".li-side span").text }

      before do
        in_project("Record the intro")
        in_project("Edit the intro")
        create(:task, title: "Water the ferns")
        create(:task, title: "Prune the roses")
        create(:task, title: "Read chapter 2")
      end

      it "lists every task with the number above the tasks whose words match", :aggregate_failures do
        get "/admin/search", q: "#2", kind: "task"

        expect(titles.first(2)).to contain_exactly("Edit the intro", "Prune the roses")
        expect(titles.last).to eq("Read chapter 2")
      end

      it "counts the label matches with the rest" do
        get "/admin/search", q: "2"

        expect(kinds).to include(["Tasks 3", nil])
      end

      it "finds a task by KEY-n in any case" do
        %w[POD-2 pod-2 #POD-2].each do |query|
          get "/admin/search", q: query, kind: "task"
          expect(titles).to eq(["Edit the intro"])
        end
      end

      it "shows each task's label" do
        get "/admin/search", q: "2", kind: "task"

        expect(labels).to contain_exactly("POD-2", "2", "3")
      end

      it "finds a task that moved by its new label" do
        ferns = Tasks::Slice["relations.tasks"].dataset.where(title: "Water the ferns")
        ferns.update(project_id: podcast.id)
        get "/admin/search", q: "POD-3", kind: "task"

        expect([titles, labels]).to eq([["Water the ferns"], ["POD-3"]])
      end
    end

    describe "a phrase a decision holds" do
      let!(:decision) { create(:decision, title: "Pick a blimp hangar", problem: "Where the airship sleeps") }

      before { get "/admin/search", q: "airship" }

      it "lists the decision under its kind" do
        expect(page.find(".card", text: "Decisions")).to have_css(".li-title", text: "Pick a blimp hangar")
      end

      it "links it to its page" do
        expect(page).to have_link(href: "/admin/decisions/#{decision.id}")
      end
    end

    describe "a phrase a pull request holds" do
      let!(:pull_request) { create(:pull_request, title: "Fix the hangar door", body: "The airship got stuck") }

      before { get "/admin/search", q: "airship" }

      it "lists the pull request under its kind" do
        expect(page.find(".card", text: "Pull requests")).to have_css(".li-title", text: "Fix the hangar door")
      end

      it "links it to its page" do
        expect(page).to have_link(href: "/admin/pull-requests/#{pull_request.id}")
      end
    end

    describe "a phrase a note holds" do
      let!(:note) { create(:note, title: "Glaze recipes", body: "Celadon over porcelain, fired in the kiln") }

      it "lists the note under its kind by its title" do
        get "/admin/search", q: "glaze"

        expect(page.find(".card", text: "Notes")).to have_css(".li-title", text: "Glaze recipes")
      end

      it "finds the note by its body" do
        get "/admin/search", q: "porcelain"

        expect(titles).to eq(["Glaze recipes"])
      end

      it "counts it under a Notes pill" do
        get "/admin/search", q: "glaze"

        expect(kinds).to include(["Notes 1", nil])
      end

      it "links it to its page" do
        get "/admin/search", q: "glaze"

        expect(page).to have_link("Glaze recipes", href: "/admin/notes/#{note.id}")
      end
    end

    describe "filtering by kind" do
      before do
        create(:task, title: "Track the zeppelin")
        create(:message, subject: "Zeppelin sighting")
        get "/admin/search", q: "zeppelin", kind: "message"
      end

      it "lists only that kind" do
        expect(titles).to eq(["Zeppelin sighting"])
      end

      it "keeps the kind chosen", :aggregate_failures do
        expect(page).to have_css(".search-kind[aria-current='page']", text: "Messages")
        expect(page).to have_field("kind", type: :hidden, with: "message")
      end

      it "still counts every kind" do
        expect(page).to have_link("All kinds 2", href: "/admin/search?q=zeppelin")
      end
    end

    it "lists every kind for a kind it does not know" do
      create(:task, title: "Track the zeppelin")
      get "/admin/search", q: "zeppelin", kind: "spaceship"

      expect(titles).to eq(["Track the zeppelin"])
    end

    describe "paging" do
      before do
        lower_page_size(:admin, to: 2)
        3.times { create(:task, title: "Call the plumber #{it}") }
        create(:message, subject: "Plumber invoice")
      end

      it "shows a page and links to the next, filter and query kept", :aggregate_failures do
        get "/admin/search", q: "plumber", kind: "task"

        expect(titles.length).to eq(2)
        expect(page).to have_css("nav.pager a[rel='next'][href='/admin/search?q=plumber&kind=task&page=2']")
      end

      it "shows the rest on the next page, filter and query kept", :aggregate_failures do
        get "/admin/search", q: "plumber", kind: "task", page: "2"

        expect(titles.length).to eq(1)
        expect(page).to have_css(".search-kind[aria-current='page']", text: "Tasks")
      end

      it "splits every match across the pages" do
        listed = %w[1 2].flat_map { |number| titles_on(number) }

        expect(listed).to contain_exactly("Call the plumber 0", "Call the plumber 1", "Call the plumber 2")
      end

      it "links back to the first page" do
        get "/admin/search", q: "plumber", kind: "task", page: "2"

        expect(page).to have_css("nav.pager a[rel='prev'][href='/admin/search?q=plumber&kind=task']")
      end

      it "returns 404 for a page past the end" do
        get "/admin/search", q: "plumber", kind: "task", page: "3"

        expect(last_response).to be_not_found
      end
    end

    describe "where each result leads" do
      it "sends a task to its page" do
        task = create(:task, :done, title: "Renew the passport")
        get "/admin/search", q: "passport"

        expect(page).to have_link("Renew the passport", href: "/admin/tasks/#{task.id}")
      end

      it "sends a journal entry to its day" do
        create(:journal_entry, entry_date: Date.new(2026, 10, 1), body: "Walked the levee at dawn")
        get "/admin/search", q: "levee"

        expect(page).to have_link("Walked the levee at dawn", href: "/admin/journal?to=2026-10-01#day-2026-10-01")
      end

      it "sends a message to its thread in Mail" do
        thread = create(:message, :read, subject: "Hello", body: "Loved your piece on sourdough")
        get "/admin/search", q: "sourdough"

        expect(page).to have_link("Hello", href: "/admin/mail?folder=all&thread=#{thread.id}#read-#{thread.id}")
      end

      it "sends a spam message to its thread in the Spam folder" do
        thread = create(:message, :spam, subject: "Hello", body: "Loved your piece on sourdough")
        get "/admin/search", q: "sourdough"

        expect(page).to have_link("Hello", href: "/admin/mail?folder=spam&thread=#{thread.id}#read-#{thread.id}")
      end

      it "lists a thread once when more than one of its messages match" do
        thread = create(:message, subject: "Hello", body: "Loved your piece on sourdough")
        create(:mail_message, mail_thread_id: thread.id, subject: "Re: Hello", body: "More sourdough questions")
        get "/admin/search", q: "sourdough"

        expect(page).to have_link("Hello", count: 1)
      end
    end

    it "dates each result" do
      create(:journal_entry, entry_date: Date.new(2026, 10, 1), body: "Walked the levee at dawn")
      get "/admin/search", q: "levee"

      expect(page).to have_css(".li-side", text: "Oct 1, 2026")
    end

    it "shows a short match" do
      create(:journal_entry, body: "Walked the levee at dawn\nThe river ran high")
      get "/admin/search", q: "river"

      expect(page).to have_css(".li-sub", text: /river/)
    end

    it "asks for a phrase when there is none", :aggregate_failures do
      create(:task, title: "Call the plumber")
      get "/admin/search"

      expect(last_response.status).to eq(200)
      expect(page).to have_css(".empty", text: says(:empty))
    end

    it "marks no pill current and shows no screen-tabs", :aggregate_failures do
      get "/admin/search", q: "zeppelin"

      expect(page).to have_no_css("a.pill-nav-link[aria-current]")
      expect(page).to have_no_css(".screen-tabs")
    end

    it "says so when nothing matches" do
      get "/admin/search", q: "zeppelin"

      expect(page).to have_css(".empty", text: says(:no_match, query: "zeppelin"))
    end
  end

  describe "signed out" do
    before do
      create(:task, title: "Email the accountant")
      get "/admin/search", q: "accountant"
    end

    it "lists nothing" do
      expect(last_response.body).not_to include("Email the accountant")
    end
  end
end
