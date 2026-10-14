# frozen_string_literal: true

RSpec.describe "Project board", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Public::Slice["i18n"] }

  def column(key) = page.find(".board-col.#{key}")

  def link(task, project)
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: project.id })
    task
  end

  def missing = i18n.t("ui.views.projects.show.missing.heading")

  describe "a public project with a published board" do
    let(:heads) { ["backlog 1", "ready 1", "in progress 1", "done 2", "canceled 1"] }
    let(:project) do
      create(
        :project,
        name: "Doing It", tagline: "Track what you do", repo: "aaronmallen/doing", url: "https://doing.aaronmallen.dev",
        stars: 40, release: "0.2.2", board_published: true,
      )
    end

    it "renders the board at the slug made from the name", :aggregate_failures do
      project
      get "/projects/doing-it"

      expect(last_response).to be_ok
      expect(page).to have_css("header.hd > .kicker + h1.board-name", exact_text: "Doing It")
    end

    it "lets caches keep it for five minutes" do
      project
      get "/projects/doing-it"

      expect(last_response.headers["Cache-Control"]).to eq("public, max-age=0, s-maxage=300")
    end

    it "shows the tagline and the stars and release", :aggregate_failures do
      project
      get "/projects/doing-it"

      expect(page).to have_css("header.hd p.ld", exact_text: "Track what you do")
      expect(page).to have_css(".board-links > span", exact_text: "★ 40 · 0.2.2")
    end

    it "links the repo and the url", :aggregate_failures do
      project
      get "/projects/doing-it"

      expect(page).to have_link("aaronmallen/doing", href: "https://github.com/aaronmallen/doing")
      expect(page).to have_link("doing.aaronmallen.dev", href: "https://doing.aaronmallen.dev")
    end

    it "leaves out the url link when it points at the repo" do
      sai = "aaronmallen/sai"
      create(:project, name: "sai", repo: sai, url: "https://github.com/#{sai}", board_published: true)
      get "/projects/sai"

      expect(page.all(".board-links a").length).to eq(1)
    end

    it "shows the five columns in order, each with a count", :aggregate_failures do
      [[], [:in_progress], [:done], [:done], [:canceled]].each { link(create(:task, *it), project) }
      link(create(:task, stage: "ready"), project)
      get "/projects/doing-it"

      expect(page.all(".board-col h2").map(&:text)).to eq(heads)
    end

    it "marks an empty column" do
      project
      get "/projects/doing-it"

      expect(column("backlog")).to have_css(".board-empty", exact_text: i18n.t("ui.views.projects.show.empty"))
    end

    it "shows only the tasks linked to the project" do
      link(create(:task, title: "Mine"), project)
      create(:task, title: "Not mine")
      get "/projects/doing-it"

      expect(page.all(".board-title").map(&:text)).to eq(["Mine"])
    end

    it "lists the open tasks in their place order" do
      %w[second first].each_with_index { |title, index| link(create(:task, title:, position: 2 - index), project) }
      get "/projects/doing-it"

      expect(column("backlog").all(".board-title").map(&:text)).to eq(%w[first second])
    end

    it "lists the closed tasks newest first" do
      link(create(:task, :done, title: "older", completed_at: Time.now - 7200), project)
      link(create(:task, :done, title: "newer", completed_at: Time.now - 60), project)
      get "/projects/doing-it"

      expect(column("done").all(".board-title").map(&:text)).to eq(%w[newer older])
    end

    it "shows a card's number, then its title", :aggregate_failures do
      task = link(create(:task, title: "Ship it"), project)
      get "/projects/doing-it"

      expect(page).to have_css("li > .board-card > .board-num + .board-title", exact_text: "Ship it")
      expect(page).to have_css(".board-num", exact_text: "##{task.id}")
    end

    it "links each card to its task page" do
      task = link(create(:task, title: "Ship it"), project)
      get "/projects/doing-it"

      expect(page).to have_css("a.board-card[href='/projects/doing-it/tasks/#{task.id}']", text: "Ship it")
    end

    it "leaves the tags, note and time off a card", :aggregate_failures do
      link(create(:task, note: "secret note", tags: %w[private-tag], worked_seconds: 3600), project)
      get "/projects/doing-it"

      expect(column("backlog").find("li").all("*").map(&:tag_name)).to eq(%w[a span span])
      expect(page).to have_no_text("secret note")
    end

    describe "on a fixed day" do
      before { allow(Time).to receive(:now).and_return(Time.utc(2026, 10, 5, 12)) }

      it "shows the day a task was done or canceled", :aggregate_failures do
        link(create(:task, :done, completed_at: Time.utc(2026, 10, 3, 18)), project)
        link(create(:task, :canceled, completed_at: Time.utc(2026, 10, 4, 18)), project)
        get "/projects/doing-it"

        expect(column("done")).to have_css(".board-meta", exact_text: "done Oct 3, 2026")
        expect(column("canceled")).to have_css(".board-meta", exact_text: "canceled Oct 4, 2026")
      end
    end

    describe "a closed task's age" do
      let(:cutoff) { Time.now - (14 * 86_400) }

      it "drops a task closed 14 days ago or more and keeps one closed since" do
        link(create(:task, :done, title: "Shipped", completed_at: cutoff), project)
        link(create(:task, :canceled, title: "Dropped", completed_at: cutoff + 60), project)
        get "/projects/doing-it"

        expect(page.all(".board-title").map(&:text)).to eq(["Dropped"])
      end

      it "keeps the page of a task off the board" do
        task = link(create(:task, :done, title: "Shipped", completed_at: cutoff - 60), project)
        get "/projects/doing-it/tasks/#{task.id}"

        expect(page).to have_css("h1", exact_text: "Shipped")
      end
    end

    it "keeps the board once the project is archived" do
      create(:project, :archived, name: "old", board_published: true)
      get "/projects/old"

      expect(page).to have_css("h1", exact_text: "old")
    end
  end

  describe "a board that is not public" do
    it "reads that the board isn't public for a private project", :aggregate_failures do
      create(:project, :private, name: "hidden", board_published: true)
      get "/projects/hidden"

      expect(last_response.status).to eq(404)
      expect(page).to have_css("h1", exact_text: missing)
      expect(page).to have_no_css(".board")
    end

    it "reads the same for a public project without the toggle" do
      create(:project, name: "plain")
      get "/projects/plain"

      expect(page).to have_css("h1", exact_text: missing)
    end

    it "reads the same for a slug no project has" do
      get "/projects/nothing"

      expect(page).to have_css("h1", exact_text: missing)
    end

    it "keeps caches from holding it" do
      get "/projects/nothing"

      expect(last_response.headers["Cache-Control"].to_s).not_to include("s-maxage")
    end
  end
end
