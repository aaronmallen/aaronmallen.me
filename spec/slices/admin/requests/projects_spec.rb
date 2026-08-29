# frozen_string_literal: true

RSpec.describe "Admin projects", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Projects::Slice["repos.project_repo"] }

  def meta = page.all(".proj-meta > span").map(&:text)

  def names = page.all(".li .li-title").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the lists" do
      before do
        create(:project, name: "live-one", position: 10)
        create(:project, :featured, name: "live-two", position: 11)
        create(:project, :archived, name: "gone", position: 12)
      end

      it "lists the live projects without a filter" do
        get "/admin/projects"

        expect(names).to eq(%w[live-one live-two])
      end

      it "lists the live projects in position order" do
        create(:project, name: "first", position: 1)
        get "/admin/projects"

        expect(names).to eq(%w[first live-one live-two])
      end

      it "lists the archived projects with the archived filter" do
        get "/admin/projects", filter: "archived"

        expect(names).to eq(%w[gone])
      end

      it "lists the live projects for a filter it doesn't know" do
        get "/admin/projects", filter: "junk"

        expect(names).to eq(%w[live-one live-two])
      end

      it "sorts the archived projects by the day they were archived, newest first" do
        create(:project, :archived, name: "older", position: 20, archived_on: Blog::TimeZone.today - 200)
        create(:project, :archived, name: "newer", position: 21, archived_on: Blog::TimeZone.today - 10)
        get "/admin/projects", filter: "archived"

        expect(names).to eq(%w[gone newer older])
      end

      it "checks the chosen segment" do
        get "/admin/projects", filter: "archived"

        expect(page).to have_css(".seg input[name='filter'][value='archived'][checked]")
      end

      it "counts the live, featured, archived and starred projects" do
        get "/admin/projects"

        expect(page).to have_css(".page-head-sub", exact_text: expected_sub)
      end

      it "counts from every project while filtered" do
        get "/admin/projects", filter: "archived"

        expect(page).to have_css(".page-head-sub", exact_text: expected_sub)
      end

      it "says projects is where you are" do
        get "/admin/projects"

        expect(page).to have_css(".ctx-where", text: %r{Publish\s+/\s+projects})
      end

      def expected_sub
        stars = Blog::Figures.count((repo.live + repo.archived).sum(&:stars))

        "2 live · 1 featured on /projects · 1 archived · #{stars} stars total"
      end
    end

    it "groups the stars with a comma over a thousand" do
      create(:project, stars: 1204)
      get "/admin/projects"

      expect(page).to have_css(".page-head-sub", text: "1,204 stars total")
    end

    describe "a row" do
      let(:attributes) do
        { name: "aube", tagline: "A node package manager", repo: "aaronmallen/aube", tags: %w[rust] }
      end
      let(:project) { create(:project, stars: 21, release: "v1.0.0", **attributes) }

      it "renders the name in mono" do
        project
        get "/admin/projects"

        expect(page).to have_css(".li-title.mono", exact_text: "aube")
      end

      it "shows the tagline" do
        project
        get "/admin/projects"

        expect(page).to have_css(".proj-tagline", exact_text: "A node package manager")
      end

      it "shows the repo, the tags, the stars and the release" do
        project
        get "/admin/projects"

        expect(meta).to eq(["aaronmallen/aube", "rust", "21", "v1.0.0"])
      end

      it "names the star count once, for a screen reader" do
        project
        get "/admin/projects"

        expect(page).to have_css(".proj-meta span[role='img'][aria-label='21 stars']", visible: :all)
      end

      it "marks the repo with the GitHub icon" do
        project
        get "/admin/projects"

        expect(page).to have_css(".proj-meta i.fa-brands.fa-github", visible: :all)
      end

      it "leaves out a meta field the project has not got" do
        create(:project, name: "bare", repo: nil, release: nil, stars: 0)
        get "/admin/projects"

        expect(meta).to eq(["0"])
      end

      it "shows the day an archived project was archived" do
        on = Blog::TimeZone.today - 30
        create(:project, :archived, name: "gone", archived_on: on)
        get "/admin/projects", filter: "archived"

        expect(page).to have_css(".proj-meta", text: "archived #{on.strftime('%b %-d, %Y')}")
      end

      it "shows a featured pill on a featured project" do
        create(:project, :featured)
        get "/admin/projects"

        expect(page).to have_css(".li-side .pill.orange", text: "featured")
      end

      it "leaves the featured pill off an unfeatured project" do
        project
        get "/admin/projects"

        expect(page).to have_no_css(".li-side .pill.orange")
      end

      it "offers Archive on a live project", :aggregate_failures do
        project
        get "/admin/projects"

        expect(page).to have_button("Archive")
        expect(page).to have_no_button("Restore")
      end

      it "offers Restore on an archived project", :aggregate_failures do
        create(:project, :archived)
        get "/admin/projects", filter: "archived"

        expect(page).to have_button("Restore")
        expect(page).to have_no_button("Archive")
      end

      it "offers no delete anywhere" do
        project
        get "/admin/projects"

        expect(page).to have_no_button("Delete")
      end
    end

    describe "the reorder carets" do
      before do
        create(:project, name: "first", position: 1)
        create(:project, name: "middle", position: 2)
        create(:project, name: "last", position: 3)
      end

      def states = page.all(".li").map { |row| row.all(".proj-caret", visible: :all).map(&:disabled?) }

      it "stacks a pair on every live row" do
        get "/admin/projects"

        expect(page).to have_css(".li .proj-move", count: 3)
      end

      it "posts each caret to the move route" do
        get "/admin/projects"
        id = repo.live.first.id

        expect(page.all(".proj-move form").first(2).map { it[:action] })
          .to eq(["/admin/projects/#{id}/move/up", "/admin/projects/#{id}/move/down"])
      end

      it "disables only the first up and the last down" do
        get "/admin/projects"

        expect(states).to eq([[true, false], [false, false], [false, true]])
      end

      it "disables both carets on a list of one" do
        repo.live.drop(1).each { repo.update(it.id, status: "archived", archived_on: Blog::TimeZone.today) }
        get "/admin/projects"

        expect(states).to eq([[true, true]])
      end

      it "names the project in each caret's label", :aggregate_failures do
        get "/admin/projects"

        expect(page).to have_css(".proj-caret[aria-label='Move first up']", visible: :all)
        expect(page).to have_css(".proj-caret[aria-label='Move first down']", visible: :all)
      end

      it "leaves the carets off the archived tab" do
        create(:project, :archived, name: "gone", position: 4)
        get "/admin/projects", filter: "archived"

        expect(page).to have_no_css(".proj-move")
      end
    end

    describe "moving" do
      let!(:one) { create(:project, name: "one", position: 1) }
      let!(:two) { create(:project, name: "two", position: 2) }

      def move(id, direction) = post("/admin/projects/#{id}/move/#{direction}", _csrf_token: admin_csrf_token)

      def order = repo.live.map(&:name)

      it "swaps a project with the one above it" do
        move(two.id, "up")

        expect(order).to eq(%w[two one])
      end

      it "swaps a project with the one below it" do
        move(one.id, "down")

        expect(order).to eq(%w[two one])
      end

      it "leaves every position unique" do
        move(two.id, "up")

        expect(repo.live.map(&:position)).to eq([1, 2])
      end

      it "redirects back to the list" do
        move(two.id, "up")

        expect(last_response).to be_redirect
          .and have_attributes(location: end_with("/admin/projects"))
      end

      it "leaves the order alone at the top" do
        move(one.id, "up")

        expect(order).to eq(%w[one two])
      end

      it "redirects back to the list at the top rather than failing" do
        move(one.id, "up")

        expect(last_response).to be_redirect
      end

      it "leaves the order alone at the bottom" do
        move(two.id, "down")

        expect(order).to eq(%w[one two])
      end

      it "reorders the public page" do
        move(two.id, "up")
        get "/projects"

        expect(page.all(".projs .proj .n").map(&:text)).to eq(%w[two one])
      end

      it "answers 404 for a project that isn't there" do
        move(0, "up")

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for an archived project", :aggregate_failures do
        gone = create(:project, :archived, name: "gone", position: 3)
        move(gone.id, "up")

        expect(last_response.status).to eq(404)
        expect(repo.by_id(gone.id).position).to eq(3)
      end

      it "answers 404 for a direction it doesn't know", :aggregate_failures do
        move(two.id, "sideways")

        expect(last_response.status).to eq(404)
        expect(order).to eq(%w[one two])
      end
    end

    describe "the status pills" do
      { "active" => "green", "wip" => "orange", "paused" => "sand" }.each do |status, color|
        it "colors #{status} #{color}" do
          create(:project, status:)
          get "/admin/projects"

          expect(page).to have_css(".li-side .pill.#{color}", text: status)
        end
      end

      it "leaves the archived pill without a color" do
        create(:project, :archived)
        get "/admin/projects", filter: "archived"

        expect(page).to have_css(".li-side .pill", text: "archived")
          .and have_no_css(".li-side .pill.green")
      end
    end

    describe "the empty states" do
      it "says nothing is live" do
        get "/admin/projects"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.projects.index.empty.live"))
      end

      it "says nothing is archived" do
        get "/admin/projects", filter: "archived"

        expect(page).to have_css(".empty", exact_text: i18n.t("ui.views.projects.index.empty.archived"))
      end
    end

    describe "the card and the note" do
      it "labels the live card for the public order", :aggregate_failures do
        get "/admin/projects"

        expect(page).to have_css(".card-label", text: "Public order")
        expect(page).to have_css(".card-title", text: "Shown on /projects")
      end

      it "labels the archived card", :aggregate_failures do
        get "/admin/projects", filter: "archived"

        expect(page).to have_css(".card-label", text: "Archive")
        expect(page).to have_css(".card-title", text: "Archived projects")
      end

      it "notes what archiving does under the live list" do
        get "/admin/projects"

        expect(page).to have_css("p.hint", exact_text: i18n.t("ui.views.projects.index.archive_note"))
      end

      it "leaves the note off the archived list" do
        get "/admin/projects", filter: "archived"

        expect(page).to have_no_css("p.hint")
      end
    end

    describe "archiving" do
      let(:project) { create(:project, :featured) }

      it "archives the project", :aggregate_failures do
        post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token
        archived = repo.by_id(project.id)

        expect(archived).to have_attributes(status: "archived", featured: false)
        expect(archived.archived_on).to eq(Blog::TimeZone.today)
      end

      it "shows the archived toast" do
        post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Archived · removed from /projects")
      end

      it "keeps the segment on the way back" do
        post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token, filter: "archived"

        expect(last_response).to be_redirect
          .and have_attributes(location: end_with("/admin/projects?filter=archived"))
      end

      it "answers 404 for a project that isn't there" do
        post "/admin/projects/0/archive", _csrf_token: admin_csrf_token

        expect(last_response.status).to eq(404)
      end

      it "refuses a project whose start month comes after today", :aggregate_failures do
        unstarted = create(:project, started_on: Blog::TimeZone.today.next_month)
        post "/admin/projects/#{unstarted.id}/archive", _csrf_token: admin_csrf_token

        expect(repo.by_id(unstarted.id)).to have_attributes(status: "active", archived_on: nil)
        expect(last_response).to be_redirect
          .and have_attributes(location: end_with("/admin/projects/#{unstarted.id}/edit"))
      end

      it "says why a project whose start month comes after today was not archived" do
        unstarted = create(:project, started_on: Blog::TimeZone.today.next_month)
        post "/admin/projects/#{unstarted.id}/archive", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Not archived · its start month has not come yet")
      end
    end

    describe "restoring" do
      let(:project) { create(:project, :archived) }

      it "restores the project", :aggregate_failures do
        post "/admin/projects/#{project.id}/restore", _csrf_token: admin_csrf_token
        restored = repo.by_id(project.id)

        expect(restored).to have_attributes(status: "active", featured: false)
        expect(restored.archived_on).to be_nil
      end

      it "shows the restored toast" do
        post "/admin/projects/#{project.id}/restore", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Restored to /projects")
      end

      it "answers 404 for a project that isn't there" do
        post "/admin/projects/0/restore", _csrf_token: admin_csrf_token

        expect(last_response.status).to eq(404)
      end

      it "answers 404 for a project that is not archived", :aggregate_failures do
        live = create(:project, :wip)
        post "/admin/projects/#{live.id}/restore", _csrf_token: admin_csrf_token

        expect(last_response.status).to eq(404)
        expect(repo.by_id(live.id).status).to eq("wip")
      end
    end
  end

  it "redirects to sign-in when signed out" do
    get "/admin/projects"

    expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
  end

  it "refuses to archive when signed out" do
    project = create(:project)
    post "/admin/projects/#{project.id}/archive"

    expect(repo.by_id(project.id).status).to eq("active")
  end

  it "refuses to move when signed out" do
    create(:project, name: "one", position: 1)
    two = create(:project, name: "two", position: 2)
    post "/admin/projects/#{two.id}/move/up"

    expect(repo.live.map(&:name)).to eq(%w[one two])
  end
end
