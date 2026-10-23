# frozen_string_literal: true

RSpec.describe "Public screens", type: :feature do
  def link_to(project, task)
    Links::Slice["operations.link_records"].call("task", task.id, { other_kind: "project", other_id: project.id })
  end

  let(:board_task) do
    project = create(:project, name: "sai", tagline: "Terminal colors", tags: %w[ruby], board_published: true)
    task = create(:task, :done, title: "Ship the palette", note: "Pick the **colors** first\n\n- [x] light\n- [ ] dark")
    blocker = create(:task, title: "Name the colors")
    [task, blocker].each { link_to(project, it) }
    create(:task, title: "Pick a tone", project_id: project.id, tags: %w[palette])
    create(:task_link, from_task_id: blocker.id, to_task_id: task.id)
    create(:task_source, task:)
    create(:task_comment, task:, body: "Looks *good*")
    Tasks::Slice["repos.task_queries"].by_id(task.id)
  end

  def screens
    {
      "about" => "/about",
      "board" => "/projects/sai?view=board",
      "board list" => "/projects/sai?view=list",
      "board filtered" => "/projects/sai?view=board&q=label:palette+author:me",
      "contact" => "/contact",
      "contact refused" => lambda do
        visit "/contact"
        click_button "Send message"
        assert_selector "#cf-email-error"
      end,
      "contact sent" => "/contact?sent=1",
      "home" => "/",
      "not found" => "/writing/nothing-here",
      "post" => "/writing/hello",
      "privacy" => "/privacy",
      "projects" => "/projects",
      "search" => "/search",
      "search nothing" => "/search?q=kafka",
      "search results" => "/search?q=palette",
      "search failed" => lambda do
        queries = Search::Slice["repos.public_search_queries"]
        allow(queries).to receive(:counts).and_raise(Sequel::DatabaseError)
        replace_component("search.repos.public_search_queries", queries)
        visit "/search?q=palette"
      end,
      "tag" => "/writing/tags/ruby",
      "task" => "/projects/sai/tasks/#{board_task.number}",
      "writing" => "/writing",
    }
  end

  before do
    create(:tag, name: "ruby", color: "mk-violet")
    board_task
    post = create(
      :post,
      :published,
      body: <<~MARKDOWN,
        prose and `code`

        ## First

        ### Under the first

        ## Second

        ## Third

        ```ruby
        # greets the reader
        class Greeter < Base
          def hello = puts("hello")
        end
        ```

        > a quote
      MARKDOWN
      slug: "hello",
      summary: "One line and no more",
      tags: %w[ruby],
      title: "A published post with a fairly long title",
    )
    create(:post_edit, post:, note: "fixed `code`", created_at: Time.utc(2026, 9, 7, 12))
    create(:post_edit, post:, note: "fixed a link", created_at: Time.utc(2026, 9, 9, 12))
    create(:post_edit, post:, note: "fixed a typo", created_at: Time.utc(2026, 9, 9, 15))
  end

  it_behaves_like "accessible screens"
  it_behaves_like "readable screens"
end
