# frozen_string_literal: true

RSpec.describe "Admin projects", :frozen_clock, type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Projects::Slice["repos.project_queries"] }

  def meta = page.all(".project-card-meta > span").map(&:text)

  def names = page.all(".project-card-name").map(&:text)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the lists" do
      before do
        create(:project, name: "live-one")
        create(:project, :private, name: "live-two")
        create(:project, :archived, name: "gone")
      end

      it "lists the live projects without a filter" do
        get "/admin/projects"

        expect(names).to eq(%w[live-one live-two])
      end

      it "lists the live projects in the order they were added" do
        create(:project, name: "newest")
        get "/admin/projects"

        expect(names).to eq(%w[live-one live-two newest])
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
        create(:project, :archived, name: "older", archived_on: Blog::TimeZone.today - 200)
        create(:project, :archived, name: "newer", archived_on: Blog::TimeZone.today - 10)
        get "/admin/projects", filter: "archived"

        expect(names).to eq(%w[gone newer older])
      end

      it "checks the chosen segment" do
        get "/admin/projects", filter: "archived"

        expect(page).to have_css(".seg input[name='filter'][value='archived'][checked]")
      end

      it "counts the live, archived and starred projects" do
        get "/admin/projects"

        expect(page).to have_css(".page-head-sub", exact_text: expected_sub)
      end

      it "counts from every project while filtered" do
        get "/admin/projects", filter: "archived"

        expect(page).to have_css(".page-head-sub", exact_text: expected_sub)
      end

      it "links to the new editor" do
        get "/admin/projects"

        expect(page).to have_link(href: "/admin/projects/new")
      end

      it "says projects is where you are" do
        get "/admin/projects"

        expect(page).to have_css(".screen-tab[aria-current='page']", text: "projects")
      end

      def expected_sub
        stars = Blog::Helpers::Figures.count((repo.live + repo.archived).sum(&:stars))

        "2 live · 1 archived · #{stars} stars total"
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

        expect(page).to have_css(".project-card-name", exact_text: "aube")
      end

      it "shows the tagline" do
        project
        get "/admin/projects"

        expect(page).to have_css(".project-card-tagline", exact_text: "A node package manager")
      end

      it "shows the repo, the stars and the release" do
        project
        get "/admin/projects"

        expect(meta).to eq(["aaronmallen/aube", "21", "v1.0.0"])
      end

      it "links each tag to its summary" do
        project
        get "/admin/projects"

        expect(page.find(".project-card-meta")).to have_link("#rust", href: "/admin/tags/rust", class: "tag")
      end

      it "names the star count once, for a screen reader" do
        project
        get "/admin/projects"

        expect(page).to have_css(".project-card-meta span[role='img'][aria-label='21 stars']", visible: :all)
      end

      it "marks the repo with the GitHub icon" do
        project
        get "/admin/projects"

        expect(page).to have_css(".project-card-meta i.fa-brands.fa-github", visible: :all)
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

        expect(page).to have_css(".project-card-meta", text: "archived #{on.strftime('%b %-d, %Y')}")
      end

      it "shows a private pill on a private project" do
        create(:project, :private)
        get "/admin/projects"

        expect(page).to have_css(".project-card-head .pill.sand", text: "private")
      end

      it "draws the private pill's icon hidden beside its label" do
        create(:project, :private)
        get "/admin/projects"

        expect(page).to have_css(".pill.sand > i.fa-lock[aria-hidden='true'] + span", exact_text: "private")
      end

      it "leaves the private pill off a public project" do
        project
        get "/admin/projects"

        expect(page).to have_no_css(".project-card-head .pill.sand")
      end

      it "offers no move controls" do
        project
        get "/admin/projects"

        expect(page).to have_no_css("form[action*='/move/']")
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

      it "links the row to its editor" do
        project
        get "/admin/projects"

        expect(page).to have_link("Edit", href: "/admin/projects/#{project.id}/edit")
      end
    end

    describe "the status pills" do
      it "colors active green" do
        create(:project)
        get "/admin/projects"

        expect(page).to have_css(".project-card-head .pill.green", text: "active")
      end

      it "leaves the archived pill without a color" do
        create(:project, :archived)
        get "/admin/projects", filter: "archived"

        expect(page).to have_css(".project-card-head .pill", text: "archived")
          .and have_no_css(".project-card-head .pill.green")
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
      it "draws each project as a card in columns" do
        create(:project, name: "aube")
        get "/admin/projects"

        expect(page).to have_css(".cols > .card.project-card", count: 1)
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
      let(:project) { create(:project, :private, repo: "aaronmallen/kept", stars: 12) }

      it "archives the project as of today and keeps the repo, the stars and the visibility" do
        post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token

        expect(repo.by_id(project.id)).to have_attributes(
          archived?: true, archived_on: Blog::TimeZone.today,
          repo: "aaronmallen/kept", stars: 12, visibility: "private",
        )
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

      it "refuses a project whose start month comes after today", :aggregate_failures do
        unstarted = create(:project, started_on: Blog::TimeZone.today.next_month)
        post "/admin/projects/#{unstarted.id}/archive", _csrf_token: admin_csrf_token

        expect(repo.by_id(unstarted.id).archived_on).to be_nil
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

      it "restores the project" do
        post "/admin/projects/#{project.id}/restore", _csrf_token: admin_csrf_token

        expect(repo.by_id(project.id)).to have_attributes(archived?: false, archived_on: nil)
      end

      it "shows the restored toast" do
        post "/admin/projects/#{project.id}/restore", _csrf_token: admin_csrf_token
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Restored to /projects")
      end

      it "answers 404 for a project that is not archived", :aggregate_failures do
        live = create(:project)
        post "/admin/projects/#{live.id}/restore", _csrf_token: admin_csrf_token

        expect(last_response.status).to eq(404)
        expect(repo.by_id(live.id).archived_on).to be_nil
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

    expect(repo.by_id(project.id).archived_on).to be_nil
  end
end
