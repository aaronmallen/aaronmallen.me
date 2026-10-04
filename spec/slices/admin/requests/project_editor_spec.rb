# frozen_string_literal: true

RSpec.describe "Admin project editor", type: :request do
  let(:i18n) { Admin::Slice["i18n"] }
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Projects::Slice["repos.project_repo"] }

  def fields(**overrides)
    { name: "sai", tagline: "Terminal colors", repo: "aaronmallen/sai", **overrides }
  end

  def save(project = nil, **overrides)
    path = project ? "/admin/projects/#{project.id}" : "/admin/projects"
    post path, _csrf_token: admin_csrf_token, project: fields(**overrides)
  end

  def tracking(name) = repo.live.find { it.repo == name }

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the new editor" do
      before { get "/admin/projects/new" }

      it "answers with the page titled New project", :aggregate_failures do
        expect(last_response).to be_ok
        expect(page).to have_title("New project | Admin | #{Blog::Owner.full_name}")
      end

      it "offers an empty name in mono" do
        expect(page).to have_css("input.editor-title.mono[name='project[name]'][value='']")
      end

      it "disables the primary action while the name is empty" do
        expect(page).to have_button("Create project", disabled: true)
      end

      it "offers no archive or restore for a project that isn't saved", :aggregate_failures do
        expect(page).to have_no_button("Archive")
        expect(page).to have_no_button("Restore")
      end

      it "heads the card holding owner/repo and the link Source", :aggregate_failures do
        card = page.find(".card-label", text: "Source").ancestor(".card")

        expect(card).to have_field("owner/repo")
        expect(card).to have_field("Link")
      end

      it "offers an empty card image" do
        expect(page).to have_css("input[type='url'][name='project[og_image_url]'][value='']")
      end

      it "links back to the list" do
        expect(page).to have_link("All projects", href: "/admin/projects", class: "editor-back")
      end

      it "posts to the create route" do
        expect(page).to have_css("form[action='/admin/projects'][method='post']")
      end
    end

    describe "the editor for a project" do
      let(:attributes) do
        {
          name: "sai", tagline: "Terminal colors", repo: "aaronmallen/sai",
          release: "v1.0.0", stars: 21, started_on: Date.new(2024, 6, 1), tags: %w[ruby cli],
        }
      end
      let(:project) { create(:project, **attributes) }

      before do
        project
        get "/admin/projects/#{project.id}/edit"
      end

      it "answers with the page titled with the project's name", :aggregate_failures do
        expect(last_response).to be_ok
        expect(page).to have_title("sai | Admin | #{Blog::Owner.full_name}")
      end

      it "fills the name" do
        expect(page).to have_css("input[name='project[name]'][value='sai']")
      end

      it "enables the primary action" do
        expect(page).to have_button("Save project", disabled: false)
      end

      it "sums up the project under the name" do
        expect(page).to have_css(".page-head-sub", text: "aaronmallen/sai · v1.0.0")
      end

      it "fills the repository and the url", :aggregate_failures do
        expect(page).to have_css("input[name='project[repo]'][value='aaronmallen/sai']")
        expect(page).to have_css("input[name='project[url]'][value='#{project.url}']")
      end

      it "fills the tagline" do
        expect(page).to have_css("textarea[name='project[tagline]']", text: "Terminal colors", visible: :all)
      end

      it "offers no description, since no public page shows one" do
        expect(page).to have_no_css("[name='project[readme]']", visible: :all)
      end

      it "fills the card image the project carries" do
        carded = create(:project, og_image_url: "https://example.com/card.png")
        get "/admin/projects/#{carded.id}/edit"

        expect(page).to have_css("input[name='project[og_image_url]'][value='https://example.com/card.png']")
      end

      it "shows the started month as a year and a month" do
        expect(page).to have_css("input[name='project[started_on]'][value='2024-06']")
      end

      it "joins the tags with a comma" do
        expect(page).to have_css("input[name='project[tags]'][value='cli, ruby']")
      end

      it "offers Archive on a live project", :aggregate_failures do
        expect(page).to have_button("Archive")
        expect(page).to have_no_button("Restore")
      end

      it "sends Archive to the archived list" do
        form = page.find("form#project-status-change[action='/admin/projects/#{project.id}/archive']", visible: :all)

        expect(form).to have_field("filter", with: "archived", type: :hidden)
      end

      it "answers 404 for a project that isn't there" do
        get "/admin/projects/0/edit"

        expect(last_response.status).to eq(404)
      end
    end

    describe "stars and release" do
      let(:project) { create(:project, stars: 1204, release: "v2.1.0") }

      before do
        project
        get "/admin/projects/#{project.id}/edit"
      end

      it "shows the stars as text, not a control", :aggregate_failures do
        expect(page).to have_css(".field-value", text: "1,204")
        expect(page).to have_no_css("[name='project[stars]']", visible: :all)
      end

      it "shows the release as text, not a control", :aggregate_failures do
        expect(page).to have_css(".field-value", text: "v2.1.0")
        expect(page).to have_no_css("[name='project[release]']", visible: :all)
      end

      it "keeps the stars and the release when the form tries to set them" do
        save(project, stars: "9999", release: "v9.9.9")

        expect(repo.by_id(project.id)).to have_attributes(stars: 1204, release: "v2.1.0")
      end
    end

    describe "the preview" do
      let(:values) { { name: "sai", tagline: "Terminal colors", tags: %w[ruby], stars: 21, release: "v1.0.0" } }

      it "renders the public card markup", :aggregate_failures do
        create(:project, **values)
        get "/admin/projects/#{repo.live.first.id}/edit"

        expect(page).to have_css(".projs .proj .n", text: "sai")
        expect(page).to have_css(".projs .proj .s", text: "ruby · ★ 21 · v1.0.0")
        expect(page).to have_css(".projs .proj p", text: "Terminal colors")
      end

      it "stands in for an empty name and tagline", :aggregate_failures do
        get "/admin/projects/new"

        expect(page).to have_css(".proj .n", text: i18n.t("ui.components.projects.preview.name_placeholder"))
        expect(page).to have_css(".proj p", text: i18n.t("ui.components.projects.preview.tagline_placeholder"))
      end
    end

    describe "creating" do
      it "saves the project", :aggregate_failures do
        save

        expect(last_response).to be_redirect
        expect(tracking("aaronmallen/sai")).to have_attributes(name: "sai", tagline: "Terminal colors")
      end

      it "saves the card image" do
        save(og_image_url: "https://example.com/card.png")

        expect(tracking("aaronmallen/sai").og_image_url).to eq("https://example.com/card.png")
      end

      it "refuses a card image that is not a link", :aggregate_failures do
        save(og_image_url: "card.png")

        expect(last_response.status).to eq(422)
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.projects.field_error.og_image_url.format"))
      end

      it "sends the editor to the saved project" do
        save

        expect(last_response.location).to end_with("/admin/projects/#{tracking('aaronmallen/sai').id}/edit")
      end

      it "says the project was created" do
        save
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Project created")
      end

      it "starts the project live at the end of the order", :aggregate_failures do
        create(:project, position: 7)
        save

        expect(tracking("aaronmallen/sai")).to have_attributes(status: "active", position: 8)
      end

      it "refuses a blank name", :aggregate_failures do
        save(name: "  ")

        expect(last_response.status).to eq(422)
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.projects.field_error.name.blank"))
      end

      it "keeps what was typed when it refuses" do
        save(name: "  ", tagline: "Terminal colors")

        expect(page).to have_css("textarea[name='project[tagline]']", text: "Terminal colors", visible: :all)
      end

      it "refuses a repository another project already tracks", :aggregate_failures do
        create(:project, repo: "aaronmallen/sai", url: "https://github.com/aaronmallen/sai")
        save

        expect(last_response.status).to eq(422)
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.projects.field_error.repo.taken"))
      end
    end

    describe "the repository and the url" do
      it "fills the url from owner/repo" do
        save(repo: "aaronmallen/sai", url: "")

        expect(tracking("aaronmallen/sai").url).to eq("https://github.com/aaronmallen/sai")
      end

      it "fills owner/repo from the url" do
        save(repo: "", url: "https://github.com/aaronmallen/sai")

        expect(tracking("aaronmallen/sai")).not_to be_nil
      end

      it "lowercases owner/repo taken from a mixed case url" do
        save(repo: "", url: "https://github.com/AaronMallen/Sai")

        expect(tracking("aaronmallen/sai").repo).to eq("aaronmallen/sai")
      end

      it "lowercases owner/repo typed in mixed case" do
        save(repo: "AaronMallen/Sai", url: "")

        expect(tracking("aaronmallen/sai").url).to eq("https://github.com/aaronmallen/sai")
      end

      it "reads owner/repo through a url with a .git suffix" do
        save(repo: "", url: "https://github.com/aaronmallen/sai.git")

        expect(tracking("aaronmallen/sai")).not_to be_nil
      end

      it "keeps both when both name the same repository" do
        save(repo: "aaronmallen/sai", url: "https://github.com/AaronMallen/sai")

        expect(tracking("aaronmallen/sai").url).to eq("https://github.com/AaronMallen/sai")
      end

      it "keeps a link to the project's own site beside the repository it tracks", :aggregate_failures do
        save(repo: "aaronmallen/gest", url: "https://gest.aaronmallen.dev")

        saved = tracking("aaronmallen/gest")
        expect(saved.url).to eq("https://gest.aaronmallen.dev")
        expect(saved.repo).to eq("aaronmallen/gest")
      end

      it "keeps the url as typed when the repository is renamed", :aggregate_failures do
        renamed = create(:project, repo: "aaronmallen/sai", url: "https://sai.aaronmallen.dev")
        save(renamed, repo: "aaronmallen/sai-next", url: "https://sai.aaronmallen.dev")

        saved = repo.by_id(renamed.id)
        expect(saved.repo).to eq("aaronmallen/sai-next")
        expect(saved.url).to eq("https://sai.aaronmallen.dev")
      end

      it "refuses a url that is not a url at all", :aggregate_failures do
        save(repo: "", url: "gest.aaronmallen.dev")

        expect(last_response.status).to eq(422)
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.projects.field_error.url.format"))
      end

      ["javascript:alert(1)", "mailto:hello@example.com", "/projects/gest"].each do |url|
        it "refuses #{url.inspect}", :aggregate_failures do
          save(repo: "aaronmallen/gest", url:)

          expect(last_response.status).to eq(422)
          expect(page).to have_css(".field-error", text: i18n.t("ui.components.projects.field_error.url.format"))
        end
      end

      it "keeps the credentials a url carries while it lowercases the host" do
        save(repo: "aaronmallen/gest", url: "https://ada:pw@Gest.Example/docs#intro")

        expect(tracking("aaronmallen/gest").url).to eq("https://ada:pw@gest.example/docs")
      end

      it "lowercases a url typed with a mixed case scheme and host" do
        save(repo: "", url: "HTTPS://GitHub.com/AaronMallen/Sai")

        expect(tracking("aaronmallen/sai").url).to eq("https://github.com/AaronMallen/Sai")
      end

      it "drops a trailing slash from the url" do
        save(repo: "", url: "https://github.com/aaronmallen/sai/")

        expect(tracking("aaronmallen/sai").url).to eq("https://github.com/aaronmallen/sai")
      end

      it "takes no owner/repo from a GitHub url whose owner cannot be an owner", :aggregate_failures do
        save(repo: "", url: "https://github.com/_foo/bar")

        saved = repo.live.first
        expect(saved.repo).to be_nil
        expect(saved.url).to eq("https://github.com/_foo/bar")
      end

      it "takes no owner/repo from a url that points inside a repository" do
        save(repo: "", url: "https://github.com/aaronmallen/sai/tree/main")

        expect(repo.live.first.repo).to be_nil
      end

      it "takes no owner/repo from a GitHub url that names no repository" do
        save(repo: "", url: "https://github.com/aaronmallen")

        expect(repo.live.first.repo).to be_nil
      end

      it "leaves both empty when neither is filled", :aggregate_failures do
        save(repo: "", url: "")

        saved = repo.live.first
        expect(saved.repo).to be_nil
        expect(saved.url).to be_nil
      end
    end

    describe "updating" do
      let(:project) { create(:project, name: "old", repo: "aaronmallen/sai") }
      let(:long_archived) do
        create(:project, :archived, archived_on: Date.new(2024, 6, 1), repo: "aaronmallen/gone",
                                    started_on: Date.new(2023, 1, 1))
      end

      it "saves the changes" do
        save(project, name: "sai")

        expect(repo.by_id(project.id).name).to eq("sai")
      end

      it "says the project was saved" do
        save(project)
        follow_redirect!

        expect(page).to have_css("[data-toast]", text: "Project saved")
      end

      it "answers 404 for a project that isn't there" do
        post "/admin/projects/0", _csrf_token: admin_csrf_token, project: fields

        expect(last_response.status).to eq(404)
      end

      it "takes a started month" do
        save(project, started_on: "2024-06")

        expect(repo.by_id(project.id).started_on).to eq(Date.new(2024, 6, 1))
      end

      it "refuses a started month it cannot read", :aggregate_failures do
        save(project, started_on: "June 2024")

        expect(last_response.status).to eq(422)
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.projects.field_error.started_on.format"))
      end

      it "takes this month as the started month" do
        today = Blog::TimeZone.today
        save(project, started_on: today.strftime("%Y-%m"))

        expect(repo.by_id(project.id).started_on).to eq(Date.new(today.year, today.month, 1))
      end

      it "refuses a started month after this month", :aggregate_failures do
        save(project, started_on: Blog::TimeZone.today.next_month.strftime("%Y-%m"))

        expect(last_response.status).to eq(422)
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.projects.field_error.started_on.future"))
      end

      it "refuses a started month after the day the project was archived", :aggregate_failures do
        save(long_archived, repo: "aaronmallen/gone", started_on: "2025-01")

        expect(last_response.status).to eq(422)
        message = i18n.t("ui.components.projects.field_error.started_on.after_archived")
        expect(page).to have_css(".field-error", text: message)
      end

      it "splits the tags on commas" do
        save(project, tags: "Ruby, CLI")

        expect(repo.by_id(project.id).tags.map(&:name)).to eq(%w[cli ruby])
      end

      it "folds one tag written two ways into one" do
        save(project, tags: "Rust, rust")

        expect(repo.by_id(project.id).tags.map(&:name)).to eq(%w[rust])
      end

      it "refuses a tag it cannot use", :aggregate_failures do
        save(project, tags: "a/b")

        expect(last_response.status).to eq(422)
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.projects.field_error.tags.format"))
      end

      it "takes the status" do
        save(project, status: "wip")

        expect(repo.by_id(project.id).status).to eq("wip")
      end

      it "refuses a status it doesn't know", :aggregate_failures do
        save(project, status: "archived")

        expect(last_response.status).to eq(422)
        expect(page).to have_css(".field-error", text: i18n.t("ui.components.projects.field_error.status.format"))
      end

      it "takes the featured toggle" do
        save(project, featured: "1")

        expect(repo.by_id(project.id).featured).to be(true)
      end

      it "clears the featured toggle" do
        featured = create(:project, :featured, repo: "aaronmallen/featured")
        save(featured, repo: "aaronmallen/featured", featured: "0")

        expect(repo.by_id(featured.id).featured).to be(false)
      end
    end

    describe "an archived project" do
      let(:project) { create(:project, :archived, repo: "aaronmallen/gone", status: "archived") }

      before do
        project
        get "/admin/projects/#{project.id}/edit"
      end

      it "offers Restore, not Archive", :aggregate_failures do
        expect(page).to have_button("Restore")
        expect(page).to have_no_button("Archive")
      end

      it "posts the restore to AA-297's route" do
        expect(page).to have_css("form[action='/admin/projects/#{project.id}/restore']", visible: :all)
      end

      it "sends Restore back to the live list" do
        form = page.find("form#project-status-change[action='/admin/projects/#{project.id}/restore']", visible: :all)

        expect(form).to have_field("filter", with: "live", type: :hidden)
      end

      it "shows the status without a control", :aggregate_failures do
        expect(page).to have_css(".pill", text: "archived")
        expect(page).to have_no_select("project[status]", visible: :all)
      end

      it "keeps the archived status when the editor saves" do
        save(project, repo: "aaronmallen/gone", status: "active")

        expect(repo.by_id(project.id)).to have_attributes(status: "archived", archived_on: project.archived_on)
      end
    end

    describe "archiving from the editor" do
      let(:project) { create(:project, :featured) }

      before do
        project
        get "/admin/projects/#{project.id}/edit"
      end

      it "posts the archive to AA-297's route" do
        expect(page).to have_css("form[action='/admin/projects/#{project.id}/archive']", visible: :all)
      end

      it "archives and unfeatures the project" do
        post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token, filter: "archived"

        expect(repo.by_id(project.id)).to have_attributes(status: "archived", featured: false)
      end

      it "sends the editor back to the archived list" do
        post "/admin/projects/#{project.id}/archive", _csrf_token: admin_csrf_token, filter: "archived"

        expect(last_response.location).to end_with("/admin/projects?filter=archived")
      end
    end

    describe "the list" do
      let(:project) { create(:project) }

      before do
        project
        get "/admin/projects"
      end

      it "offers New project" do
        expect(page).to have_link("New project", href: "/admin/projects/new", class: %w[btn pri])
      end

      it "offers Edit on a row" do
        expect(page).to have_css(".li-side a[href='/admin/projects/#{project.id}/edit']", text: "Edit")
      end

      it "links the name to the editor" do
        expect(page).to have_css("a.li-title[href='/admin/projects/#{project.id}/edit']", text: project.name)
      end
    end
  end

  describe "signed out" do
    it "redirects the new editor to sign-in" do
      get "/admin/projects/new"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "redirects the editor to sign-in" do
      get "/admin/projects/#{create(:project).id}/edit"

      expect(last_response).to be_redirect.and have_attributes(location: end_with("/admin/sign-in"))
    end

    it "refuses to create" do
      post "/admin/projects", project: { name: "sai" }

      expect(repo.live).to be_empty
    end
  end
end
