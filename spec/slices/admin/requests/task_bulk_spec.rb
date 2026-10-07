# frozen_string_literal: true

RSpec.describe "Admin bulk task actions", :frozen_clock, type: :request do
  let(:page) { Capybara.string(last_response.body) }
  let(:repo) { Tasks::Slice["repos.task_queries"] }

  def act(name, tasks, **params)
    ids = tasks.map { it.is_a?(Integer) ? it : it.id }
    post "/admin/tasks/bulk", { _csrf_token: admin_csrf_token, act: name, ids:, filter: "next", **params }
  end

  def event(kind, from_list: nil, to_list: nil, tag_name: nil) = { kind:, from_list:, to_list:, tag_name: }

  def events(task)
    found = Tasks::Slice["relations.task_events"].for_task(task.id).in_order.to_a

    found.map { it.to_h.slice(:kind, :from_list, :to_list, :tag_name) }
  end

  def gone_id = create(:task).id.tap { Tasks::Slice["repos.task_mutations"].delete(it) }

  def place(task) = repo.by_id(task.id).place

  def status(task) = repo.by_id(task.id)&.status

  def tag_names(task) = Tasks::Slice["relations.task_tags"].names_by_task([task.id]).fetch(task.id, [])

  def tagged(*names) = create(:task).tap { Tasks::Slice["repos.task_mutations"].replace_tags(it.id, names) }

  def tasks(count) = Array.new(count) { create(:task) }

  def toast = page.find("[data-toast] .toast", visible: :all).text(:all)

  describe "signed in" do
    before { sign_in_to_admin }

    describe "the list" do
      before { tasks(2) }

      it "draws one bar that posts to the bulk route", :aggregate_failures do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("form#task-bulk[action='/admin/tasks/bulk'][method='post']", count: 1)
        expect(page.all("form#task-bulk button[name='act']").map(&:value)).to eq(%w[complete cancel move tag untag
                                                                                    delete])
      end

      it "gives each row a box that joins the bar" do
        get "/admin/tasks", filter: "next"

        expect(page.all(".task input[type='checkbox'][name='ids[]'][form='task-bulk']").size).to eq(2)
      end

      it "names the task on each box" do
        task = create(:task, title: "Email the accountant")
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("input[value='#{task.id}'][aria-label='Select Email the accountant']")
      end

      it "shows the actions in the markup, so they work with scripts off" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("[data-bulk-acts]:not([hidden])")
      end

      it "leaves select all for the script to draw" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("[data-bulk-all][hidden]", visible: :all)
      end

      it "offers every list to move to" do
        get "/admin/tasks", filter: "next"

        options = page.all("form#task-bulk select[name='to'] option").map(&:value)

        expect(options).to eq(["", "today", "next", "someday", "external"])
      end

      it "draws a labelled tag field in the bar" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("form#task-bulk input[name='tag'][aria-label='Tag name']")
      end

      it "asks before deleting" do
        get "/admin/tasks", filter: "next"

        expect(page).to have_css("button[value='delete'][data-confirm]")
      end

      it "keeps the search and the page in the bar", :aggregate_failures do
        2.times { create(:task, title: "Plan a trip") }
        lower_page_size(:admin, to: 1)
        get "/admin/tasks", filter: "next", page: 2, q: "a"

        expect(page).to have_css("form#task-bulk input[name='q'][value='a']", visible: :all)
        expect(page).to have_css("form#task-bulk input[name='page'][value='2']", visible: :all)
      end

      it "draws no bar on the archive" do
        create(:task, :done)
        get "/admin/tasks", filter: "completed"

        expect(page).to have_no_css("form#task-bulk")
      end
    end

    describe "an empty list" do
      it "draws no bar" do
        get "/admin/tasks", filter: "someday"

        expect(page).to have_no_css("form#task-bulk")
      end
    end

    {
      "complete" => ["done", "Finished 2 tasks"],
      "cancel" => ["canceled", "Canceled 2 tasks"],
    }.each do |name, (changed, said)|
      describe "#{name} on the ticked tasks" do
        let!(:ticked) { tasks(2) }
        let!(:left) { create(:task) }

        before { act(name, ticked) }

        it "changes them" do
          expect(ticked.map { status(it) }).to eq([changed, changed])
        end

        it "leaves the rest alone" do
          expect(status(left)).to eq("open")
        end

        it "says how many changed" do
          follow_redirect!

          expect(toast).to eq(said)
        end
      end
    end

    describe "delete on the ticked tasks" do
      let!(:ticked) { tasks(2) }
      let!(:left) { create(:task) }

      before { act("delete", ticked) }

      it "takes them away" do
        expect(ticked.map { status(it) }).to eq([nil, nil])
      end

      it "leaves the rest alone" do
        expect(status(left)).to eq("open")
      end

      it "says how many went" do
        follow_redirect!

        expect(toast).to eq("Deleted 2 tasks")
      end
    end

    describe "move on the ticked tasks" do
      let!(:ticked) { tasks(2) }
      let!(:left) { create(:task) }

      before { act("move", ticked, to: "someday") }

      it "puts them on the list" do
        expect(ticked.map { place(it) }).to eq(%w[someday someday])
      end

      it "leaves the rest alone" do
        expect(place(left)).to eq("next")
      end

      it "records a move on each" do
        expect(ticked.map { events(it) }).to all(eq([event("moved", from_list: "next", to_list: "someday")]))
      end

      it "records nothing on the rest" do
        expect(events(left)).to be_empty
      end

      it "says how many moved and where" do
        follow_redirect!

        expect(toast).to eq("Moved 2 tasks to someday")
      end
    end

    describe "move into the sprint" do
      let!(:ticked) { tasks(2) }

      before { act("move", ticked, to: "today") }

      it "puts them in today's sprint", :aggregate_failures do
        sprint = Tasks::Slice["repos.sprint_queries"].on(Blog::TimeZone.today)

        expect(ticked.map { repo.by_id(it.id).sprint_id }).to eq([sprint.id, sprint.id])
        expect(ticked.map { place(it) }).to eq(%w[today today])
      end

      it "records a move off the list on each" do
        expect(ticked.map { events(it).map { |event| event.slice(:kind, :from_list) } })
          .to all(eq([{ kind: "moved", from_list: "next" }]))
      end
    end

    describe "tag on the ticked tasks" do
      let!(:ticked) { [tagged("home"), tagged] }
      let!(:left) { tagged("home") }

      before { act("tag", ticked, tag: " Money ") }

      it "adds the tag and keeps the others" do
        expect(ticked.map { tag_names(it) }).to eq([%w[home money], %w[money]])
      end

      it "leaves the rest alone" do
        expect(tag_names(left)).to eq(%w[home])
      end

      it "records the tag on each" do
        expect(ticked.map { events(it) }).to all(eq([event("tagged", tag_name: "money")]))
      end

      it "says how many it tagged" do
        follow_redirect!

        expect(toast).to eq("Tagged 2 tasks money")
      end
    end

    describe "tag on a task that has it already" do
      it "keeps one and records nothing", :aggregate_failures do
        task = tagged("money")
        act("tag", [task], tag: "money")

        expect(tag_names(task)).to eq(%w[money])
        expect(events(task)).to be_empty
      end
    end

    describe "untag on the ticked tasks" do
      let!(:ticked) { [tagged("home", "money"), tagged("money")] }
      let!(:left) { tagged("money") }

      before { act("untag", ticked, tag: "money") }

      it "takes the tag off and keeps the others" do
        expect(ticked.map { tag_names(it) }).to eq([%w[home], []])
      end

      it "leaves the rest alone" do
        expect(tag_names(left)).to eq(%w[money])
      end

      it "records the untag on each" do
        expect(ticked.map { events(it) }).to all(eq([event("untagged", tag_name: "money")]))
      end

      it "says how many it untagged" do
        follow_redirect!

        expect(toast).to eq("Took money off 2 tasks")
      end
    end

    describe "one ticked task" do
      {
        "cancel" => [{}, "Canceled 1 task"],
        "delete" => [{}, "Deleted 1 task"],
        "move" => [{ to: "external" }, "Moved 1 task to external"],
        "untag" => [{ tag: "money" }, "Took money off 1 task"],
      }.each do |name, (params, said)|
        it "says #{name} changed one" do
          act(name, [tagged("money")], **params)
          follow_redirect!

          expect(toast).to eq(said)
        end
      end
    end

    describe "a move back to next" do
      let!(:ticked) { Array.new(2) { create(:task, list: "someday") } }

      before { act("move", ticked, to: "next") }

      it "says how many moved and where" do
        follow_redirect!

        expect(toast).to eq("Moved 2 tasks to next")
      end
    end

    describe "a batch refused for a reason the bar does not name" do
      let(:task) { create(:task, title: "Held") }

      before do
        replace_component(
          "tasks.operations.act_on_tasks",
          ->(_params) { Dry::Monads::Result::Failure.new([:record, task.id, :locked]) },
        )
        act("complete", [task])
      end

      it "names the task in the toast" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · ##{task.id} Held would not change")
      end
    end

    describe "a move or tag change with a task that is gone" do
      let!(:ticked) { [tagged("money"), tagged("money")] }
      let(:missing) { gone_id }

      {
        "move" => { to: "someday" },
        "tag" => { tag: "home" },
        "untag" => { tag: "money" },
      }.each do |name, input|
        it "#{name} changes nothing", :aggregate_failures do
          act(name, [*ticked, missing], **input)

          expect(ticked.map { place(it) }).to eq(%w[next next])
          expect(ticked.map { tag_names(it) }).to eq([%w[money], %w[money]])
        end

        it "#{name} records no events" do
          act(name, [*ticked, missing], **input)

          expect(ticked.flat_map { events(it) }).to be_empty
        end

        it "#{name} names the task" do
          act(name, [*ticked, missing], **input)
          follow_redirect!

          expect(toast).to eq("Nothing changed · ##{missing} is gone")
        end
      end
    end

    describe "a batch with a task that is gone" do
      let!(:ticked) { tasks(2) }
      let(:missing) { gone_id }

      %w[complete cancel delete].each do |name|
        it "#{name} changes nothing" do
          act(name, [*ticked, missing])

          expect(ticked.map { status(it) }).to eq(%w[open open])
        end
      end

      it "names the task in the toast" do
        act("complete", [*ticked, missing])
        follow_redirect!

        expect(toast).to eq("Nothing changed · ##{missing} is gone")
      end
    end

    describe "a cancel that reaches a closed task" do
      let!(:ticked) { create(:task) }
      let!(:closed) { create(:task, :done, title: "Filed already") }

      before { act("cancel", [ticked, closed]) }

      it "changes nothing" do
        expect(status(ticked)).to eq("open")
      end

      it "names the task and why" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · ##{closed.id} Filed already is closed already")
      end
    end

    describe "a complete that reaches a closed task" do
      let!(:ticked) { create(:task) }
      let(:closed_at) { Time.now.round - 86_400 }
      let!(:closed) { create(:task, :canceled, completed_at: closed_at, title: "Dropped") }

      before { act("complete", [ticked, closed]) }

      it "changes nothing", :aggregate_failures do
        expect(status(ticked)).to eq("open")
        expect(repo.by_id(closed.id)).to have_attributes(status: "canceled", completed_at: closed_at)
      end

      it "names the task and why" do
        follow_redirect!

        expect(toast).to eq("Nothing changed · ##{closed.id} Dropped is closed already")
      end
    end

    describe "where it lands" do
      it "goes back to the list it came from" do
        act("complete", [create(:task, :someday)], filter: "someday")

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=someday")
      end

      it "keeps the search" do
        act("complete", [create(:task)], q: "tag:site")

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=next&q=tag:site")
      end

      it "keeps the page while it still has rows" do
        lower_page_size(:admin, to: 1)
        tasks(3)
        act("complete", [repo.in_list("next").last], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=next&page=2")
      end

      it "steps back a page when the batch emptied the last one" do
        lower_page_size(:admin, to: 1)
        tasks(2)
        act("complete", [repo.in_list("next").last], page: 2)

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=next")
      end

      it "goes back the same way after a failure" do
        act("complete", [gone_id], filter: "someday")

        expect(last_response.headers["location"]).to eq("/admin/tasks?filter=someday")
      end
    end

    describe "a refused batch" do
      it "asks for a tick when none came" do
        post "/admin/tasks/bulk", { _csrf_token: admin_csrf_token, act: "complete", filter: "next" }
        follow_redirect!

        expect(toast).to eq("Tick a task first")
      end

      it "refuses more than 100 tasks before it changes any", :aggregate_failures do
        tasks = tasks(101)
        act("complete", tasks)
        follow_redirect!

        expect(toast).to eq("Tick 100 tasks or fewer")
        expect(repo.in_list("next").size).to eq(101)
      end

      it "counts a repeated task once" do
        task = create(:task)
        act("complete", Array.new(101, task.id))
        follow_redirect!

        expect(toast).to eq("Finished 1 task")
      end

      it "asks for a list before a move", :aggregate_failures do
        task = create(:task)
        act("move", [task], to: "")
        follow_redirect!

        expect(toast).to eq("Pick a list first")
        expect(place(task)).to eq("next")
      end

      it "asks for a tag before a tag change" do
        act("tag", [create(:task)], tag: " ")
        follow_redirect!

        expect(toast).to eq("Type a tag first")
      end

      it "refuses a tag that is not a slug", :aggregate_failures do
        task = create(:task)
        act("tag", [task], tag: "not a tag!")
        follow_redirect!

        expect(toast).to eq("Nothing changed · a tag takes lowercase letters, numbers and dashes")
        expect(tag_names(task)).to be_empty
      end

      it "ignores the move and tag fields on other actions" do
        task = create(:task)
        act("complete", [task], to: "", tag: "not a tag!")

        expect(status(task)).to eq("done")
      end

      it "refuses an action off the bar", :aggregate_failures do
        task = create(:task)
        act("archive", [task])
        follow_redirect!

        expect(toast).to eq("Nothing changed · pick an action from the bar")
        expect(status(task)).to eq("open")
      end
    end
  end

  describe "signed out" do
    it "changes nothing" do
      task = create(:task)
      post "/admin/tasks/bulk", { act: "complete", ids: [task.id] }

      expect(status(task)).to eq("open")
    end
  end
end
