# frozen_string_literal: true

RSpec.describe "Project board", type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:i18n) { Public::Slice["i18n"] }

  def column(key) = page.find(".board-col.#{key}")

  def group(key) = page.find(".board-group.#{key}")

  def link(task, project)
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: project.id })
    Tasks::Slice["repos.task_queries"].by_id(task.id)
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

    it "opens the oldest board when names saved before the check share its slug" do
      project
      create(:project, name: "doing-it", tagline: "Newer", board_published: true)
      get "/projects/doing-it"

      expect(page).to have_css("h1.board-name", exact_text: "Doing It")
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
      link(create(:task, title: "Ship it"), project)
      get "/projects/doing-it"

      expect(page).to have_css("li > .board-card > .board-num + .board-title", exact_text: "Ship it")
      expect(page).to have_css(".board-num", exact_text: "DOI-1")
    end

    it "links each card to its task page" do
      task = link(create(:task, title: "Ship it"), project)
      get "/projects/doing-it"

      expect(page).to have_css("a.board-card[href='/projects/doing-it/tasks/#{task.number}']", text: "Ship it")
    end

    it "leaves the note and time off a card", :aggregate_failures do
      link(create(:task, note: "secret note", worked_seconds: 3600), project)
      get "/projects/doing-it"

      expect(column("backlog").find("li").all("*").map(&:tag_name)).to eq(%w[a span span])
      expect(page).to have_no_text("secret note")
    end

    it "counts the open and all tasks in the bar" do
      [[], [:in_progress], [:done], [:canceled]].each { link(create(:task, *it), project) }
      get "/projects/doing-it"

      expect(page).to have_css(".board-bar > .meta", exact_text: "2 open · 4 total")
    end

    it "draws a view switch with both views unpressed", :aggregate_failures do
      project
      get "/projects/doing-it"

      expect(page.all(".board-switch button[aria-pressed='false']").map(&:text)).to eq(%w[board list])
      expect(page).to have_css(".board-switch[role='group'][aria-label='View']")
    end

    describe "the list" do
      it "draws a group per column in order, each with a count" do
        [[], [:in_progress], [:done], [:done], [:canceled]].each { link(create(:task, *it), project) }
        link(create(:task, stage: "ready"), project)
        get "/projects/doing-it"

        expect(page.all(".board-group > summary").map(&:text)).to eq(heads)
      end

      it "opens every group but canceled" do
        project
        get "/projects/doing-it"

        expect(page.all(".board-group").map { it[:open].nil? }).to eq([false, false, false, false, true])
      end

      it "marks an empty group" do
        project
        get "/projects/doing-it"

        expect(group("backlog")).to have_css(".board-empty", exact_text: i18n.t("ui.views.projects.show.empty"))
      end

      it "links a row to its task page with its number and title", :aggregate_failures do
        task = link(create(:task, title: "Ship it"), project)
        get "/projects/doing-it"

        row = group("backlog").find("a.board-row[href='/projects/doing-it/tasks/#{task.number}']")
        expect(row.all("span").map(&:text)).to eq(["DOI-1", "Ship it"])
      end

      it "leaves the note and time off a row", :aggregate_failures do
        link(create(:task, note: "secret note", worked_seconds: 3600), project)
        get "/projects/doing-it"

        expect(group("backlog").find("li").all("*").map(&:tag_name)).to eq(%w[a span span])
        expect(page).to have_no_text("secret note")
      end
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

      it "shows the same day on a list row", :aggregate_failures do
        link(create(:task, :done, completed_at: Time.utc(2026, 10, 3, 18)), project)
        link(create(:task, :canceled, completed_at: Time.utc(2026, 10, 4, 18)), project)
        get "/projects/doing-it"

        expect(group("done")).to have_css(".board-row-meta", exact_text: "done Oct 3, 2026")
        expect(group("canceled")).to have_css(".board-row-meta", exact_text: "canceled Oct 4, 2026", visible: :all)
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
        get "/projects/doing-it/tasks/#{task.number}"

        expect(page).to have_css("h1", exact_text: "Shipped")
      end
    end

    describe "a full column" do
      def days_ago(days) = Time.now - (days * 86_400)

      def more(key) = column(key).find("a.board-more")

      def titles(key) = column(key).all(".board-title").map(&:text)

      before do
        override_setting(:board, :column_size, to: 2)
        3.times { link(create(:task, title: "Plan #{it}"), project) }
        3.times { link(create(:task, stage: "ready", title: "Ready #{it}"), project) }
      end

      it "shows the cap and links to the rest", :aggregate_failures do
        get "/projects/doing-it"

        expect(titles("backlog").size).to eq(2)
        expect(more("backlog")).to have_text("Load more · 1 left")
        expect(more("backlog")[:href]).to eq("/projects/doing-it?backlog=4&view=board")
      end

      it "grows only that column", :aggregate_failures do
        get "/projects/doing-it", backlog: 4

        expect([titles("backlog").size, titles("ready").size]).to eq([3, 2])
        expect(column("backlog")).to have_no_css("a.board-more")
        expect(more("ready")[:href]).to eq("/projects/doing-it?backlog=4&ready=4&view=board")
      end

      it "never shows fewer than the cap" do
        get "/projects/doing-it", backlog: 1

        expect(titles("backlog").size).to eq(2)
      end

      it "ignores a size that is not a number" do
        get "/projects/doing-it", backlog: "lots"

        expect(titles("backlog").size).to eq(2)
      end

      it "counts every task in the column heads" do
        get "/projects/doing-it"

        expect(page.all(".board-col h2 .n").map(&:text)).to eq(%w[3 3 0 0 0])
      end

      it "leaves old closed tasks out of the count and Load More", :aggregate_failures do
        2.times { link(create(:task, :done, completed_at: days_ago(1)), project) }
        link(create(:task, :done, completed_at: days_ago(30)), project)
        get "/projects/doing-it"

        expect(column("done").find("h2 .n").text).to eq("2")
        expect(column("done")).to have_no_css("a.board-more")
      end

      it "caps each group and links its Load More to the list", :aggregate_failures do
        get "/projects/doing-it", backlog: 4

        expect(group("backlog").all(".board-row").size).to eq(3)
        expect(group("backlog")).to have_no_css("a.board-more")
        expect(group("ready").all(".board-row").size).to eq(2)
        expect(group("ready").find("a.board-more")[:href]).to eq("/projects/doing-it?backlog=4&ready=4&view=list")
      end

      it "leaves old closed tasks out of a group" do
        link(create(:task, :done, title: "Old", completed_at: days_ago(30)), project)
        get "/projects/doing-it"

        expect(group("done")).to have_css(".board-empty")
      end

      it "shows the latest closed tasks first" do
        [["Oldest", 3], ["Newest", 1], ["Middle", 2]].each do |title, days|
          link(create(:task, :canceled, title:, completed_at: days_ago(days)), project)
        end
        get "/projects/doing-it"

        expect(titles("canceled")).to eq(%w[Newest Middle])
      end
    end

    describe "its tags and filter" do
      def choices = JSON.parse(page.find("[data-task-filter]")["data-task-filter"])

      def tag_into(task, tag)
        Tasks::Slice["relations.task_tags"].insert(task_id: task.id, tag_id: tag.id, tag_scope: tag.scope)
      end

      def task_in(project, *, **) = create(:task, *, project_id: project.id, **)

      it "shows the project tags on a card and a row", :aggregate_failures do
        task_in(project, tags: %w[audio])
        get "/projects/doing-it"

        expect(column("backlog")).to have_css("li > .board-tags > a.tag", exact_text: "#audio")
        expect(group("backlog")).to have_css("li > .board-row-tags > a.tag", exact_text: "#audio", visible: :all)
      end

      it "links a tag to the board filtered by it" do
        task_in(project, tags: %w[audio])
        get "/projects/doing-it"

        expect(column("backlog").find("a.tag")[:href]).to eq("/projects/doing-it?q=label:audio")
      end

      it "adds a tag to the filter already on" do
        task_in(project, title: "Record the intro", tags: %w[audio])
        get "/projects/doing-it", q: "intro"

        expect(column("backlog").find("a.tag")[:href]).to eq("/projects/doing-it?q=intro%20label:audio")
      end

      it "leaves a tag link as it is when the filter holds the tag" do
        task_in(project, tags: %w[audio])
        get "/projects/doing-it", q: "label:audio"

        expect(column("backlog").find("a.tag")[:href]).to eq("/projects/doing-it?q=label:audio")
      end

      it "leaves off a private tag and another project's tag" do
        task = task_in(project, tags: %w[audio])
        tag_into(task, create(:tag, :private, name: "secret"))
        tag_into(task, create(:tag, scope: "project", project_id: create(:project, :private).id, name: "theirs"))
        get "/projects/doing-it"

        expect(page.all("a.tag", visible: :all).map(&:text)).to eq(["#audio", "#audio"])
      end

      it "offers the project tags in the filter bar", :aggregate_failures do
        task_in(project, tags: %w[audio])
        task_in(create(:project, :private), tags: %w[hidden])
        get "/projects/doing-it"

        expect(page).to have_css("form.task-filter-box[action='/projects/doing-it'][method='get'] input[name='q']")
        expect(choices["tags"].map(&:first)).to eq(%w[audio])
      end

      it "filters the board and the list and counts the matches", :aggregate_failures do
        task_in(project, title: "Record the intro", tags: %w[audio])
        task_in(project, title: "Book a guest")
        get "/projects/doing-it", q: "label:audio"

        expect(page.all(".board-title, .board-row-title", visible: :all).map(&:text)).to eq(["Record the intro"] * 2)
        expect(page.find(".task-filter-meta")).to have_text("1 of 2 tasks match")
      end

      it "keeps the filter in the field and in Load More", :aggregate_failures do
        override_setting(:board, :column_size, to: 1)
        2.times { task_in(project, tags: %w[audio]) }
        get "/projects/doing-it", q: "label:audio"

        expect(page).to have_field("q", with: "label:audio")
        expect(column("backlog").find("a.board-more")[:href]).to end_with("?backlog=2&q=label:audio&view=board")
      end

      it "keeps the tags of a board that is not published off its page", :aggregate_failures do
        hidden = create(:project, name: "unlisted")
        task_in(hidden, tags: %w[unlisted-tag])
        get "/projects/unlisted"

        expect(page).to have_no_css("[data-task-filter]")
        expect(last_response.body).not_to include("unlisted-tag")
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
