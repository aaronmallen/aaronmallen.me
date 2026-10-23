Feature: Admin agent sessions
  The sessions screen lists each agent run by day, and its drawer shows what the run read, searched, changed and wrote.

  Background:
    Given I am signed in to the admin
    And the task "Index the activities table"

  Scenario: The list sits under the Agents pill, groups by day and counts each run's work
    Given the project "The blog" in the repo "aaronmallen/blog"
    And the agent starts the session "Spec the link check"
    And the agent ends its session
    And the session "Spec the link check" started 1 day ago and ran 30 minutes
    And the agent starts the session "Index the activities table" with:
      | client | Claude Code 2.4  |
      | repo   | aaronmallen/blog |
      | branch | index            |
    And the agent files the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    And the agent writes the plan "Index plan"
    And I note the ids of "hanami"
    When I visit "/admin/agents/sessions"
    Then the text of "a.pill-nav-link[aria-current='page']" holds "Agents"
    And the text of "h1.page-head-title" is "Agents"
    And the texts of "a.screen-tab" are:
      | memories 1 fact    |
      | artifacts 1        |
      | sessions 1 running |
    And the texts of ".agent-days .day-head .day-note" are:
      | Today · 1     |
      | Yesterday · 1 |
    And the page counts 2 of ".card.agent-days > .card-body > .activity-day"
    And the text of "#agent-session-{session} .pill" holds "running"
    And the text of ".agent-days .li:has-text('Spec the link check') .li-side" holds "30m"
    And the texts of "#agent-session-{session} .task-meta span" are:
      | {clock}–now               |
      | Anthropic claude-opus-5-5 |
      | The blog                  |
      | blog @ index              |
      | 0 files read              |
      | 0 searches                |
      | 2 memory changes          |
      | 1 artifact                |
    And the page has "#agent-session-{session} .task-meta span:has-text('The blog') i.fa-cube"
    And the page has "#agent-session-{session} .task-meta span:has-text('blog @ index') i.fa-brands.fa-github"
    And "#agent-session-{session} .task-meta span:text-is('Anthropic claude-opus-5-5')" has the "title" "via claude-code"
    And the texts of "select[name='project'] option" are:
      | Every project |
      | The blog      |
    And the text of ".page-head-sub" is "1 session today, 1 still running. 2 in the last 2 days."
    And the page has no "#agent-session"
    And "#agent-session-{session} a.li-title" has the "href" "/admin/agents/sessions?session={session}"
    And the page has no axe breaches in light or dark

  Scenario: Filtering by project lists only its sessions and keeps the filter on each row
    Given the project "The blog" in the repo "aaronmallen/blog"
    And the agent starts the session "Elsewhere"
    And the agent starts the session "Index the activities table" with:
      | repo | aaronmallen/blog |
    And I note the ids of "nothing"
    When I visit "/admin/agents/sessions?project={project1}"
    Then the page counts 1 of ".agent-days .li"
    And "#agent-session-{session} a.li-title" has the "href" "/admin/agents/sessions?project={project1}&session={session}"
    And "select[name='project'] option[selected]" has the "value" "{project1}"

  Scenario: A row counts files read, repeats included, and searches run
    Given I file the global memory "preferences" described "Notes"
    And the agent starts the session "Index the activities table"
    And the agent reads "preferences" in its session
    And the agent reads "preferences" in its session
    And the agent searches memory for "cache"
    When I visit "/admin/agents/sessions"
    Then the text of "#agent-session-{session} .task-meta" holds "2 files read"
    And the text of "#agent-session-{session} .task-meta" holds "1 search"

  Scenario: With no session the list says so, and an unknown session opens no drawer
    When I visit "/admin/agents/sessions"
    Then the text of ".agent-days" holds "No agent has opened a session yet"
    When I visit "/admin/agents/sessions?session=999999"
    Then the page has no "#agent-session"

  Scenario: The drawer names the run, its agent, client and tasks, and what it read, changed and wrote
    Given the agent starts the session "Index the activities table" with:
      | client | Claude Code 2.4            |
      | tasks  | Index the activities table |
    And I file the global memory "preferences" described "Notes"
    And the session loaded "preferences" before reads were recorded
    And the agent files the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    And the agent writes the plan "Index plan"
    And the agent describes "hanami" as "How we test"
    And I note the ids of "hanami"
    When I open the session "Index the activities table"
    Then the text of "#agent-session h3" holds "Index the activities table"
    And the texts of "#agent-session .agent-session-meta > span:nth-child(-n+2)" are:
      | claude-code on Anthropic claude-opus-5-5 |
      | via Claude Code 2.4                      |
    And the text of "#agent-session .field:has(> .f:text-is('Worked on')) .meta" holds "#{task1}"
    And "#agent-session .field:has(> .f:text-is('Worked on')) a:has-text('Index the activities table')" has the "href" "/admin/tasks/{task1}"
    And the texts of "#agent-session .field:has(> .f:text-is('Memory it read')) .record-link-title" are:
      | preferences.md |
    And the text of "#agent-session .field:has(> .f:text-is('Memory it read')) .hint" holds "ran before the site recorded searches and reads"
    And the texts of "#agent-session .field > .f" are:
      | Worked on          |
      | Memory it read     |
      | Memory it changed  |
      | Artifacts it wrote |
      | Tags               |
    And the texts of "#agent-session .field:has(> .f:text-is('Memory it changed')) a.agent-change > .meta" are:
      | created hanami.md                    |
      | added to hanami.md                   |
      | changed the description of hanami.md |
    And the text of "#agent-session .field:has(> .f:text-is('Memory it changed')) .agent-change-text" holds "Run specs through mise"
    And the text of "#agent-session .field:has(> .f:text-is('Artifacts it wrote')) .record-link-title" holds "· v1 Index plan"
    And the page has no axe breaches in light or dark

  Scenario: The drawer shows the project, repo and branch, and links the project to its sessions
    Given the project "The blog" in the repo "aaronmallen/blog"
    And the agent starts the session "Spike" with:
      | repo   | aaronmallen/blog |
      | branch | index            |
    And I note the ids of "nothing"
    When I open the session "Spike"
    Then the texts of "#agent-session .agent-session-meta > :nth-child(n+2):nth-child(-n+3)" are:
      | The blog                 |
      | aaronmallen/blog @ index |
    And "#agent-session .agent-session-meta a:has-text('The blog')" has the "href" "/admin/agents/sessions?project={project1}"

  Scenario: The index it started with follows Worked on and keeps each line as the agent got it
    Given I file the global memory "gone" described "Old notes"
    And I file the global memory "hanami" described "Hanami notes"
    And I add the gotcha "Run specs through mise" to "hanami"
    And the agent starts the session "Index the activities table" with:
      | tasks | Index the activities table |
    And I describe "hanami" as "Newer notes"
    And I delete the memory file "gone"
    And I note the ids of "hanami"
    When I open the session "Index the activities table"
    Then the texts of "#agent-session .field > .f" are:
      | Worked on             |
      | Index it started with |
      | Searches              |
      | Files read            |
      | Memory it changed     |
      | Artifacts it wrote    |
      | Tags                  |
    And the texts of "#agent-session .field:has(> .f:text-is('Index it started with')) .memory-line" are:
      | global a deleted file0 factsOld notes |
      | global hanami.md1 factHanami notes    |
    And "#agent-session .field:has(> .f:text-is('Index it started with')) a:has-text('hanami.md')" has the "href" "/admin/agents/memories/{file}"
    And the page has "#agent-session .field:has(> .f:text-is('Index it started with')) span.record-link-title:has-text('a deleted file')"
    And the page has no "#agent-session .field:has(> .f:text-is('Index it started with')) a:has-text('a deleted file')"

  Scenario: The index marks a description an agent wrote
    Given the agent files the global memory "agent" described "By an agent"
    And the agent starts the session "Later run"
    When I open the session "Later run"
    Then the page has "#agent-session .field:has(> .f:text-is('Index it started with')) .memory-line:has-text('agent.md') .agent-mark i.fa-robot"

  Scenario: A run with no search says None., and searches follow the index
    Given the agent starts the session "Index the activities table"
    When I open the session "Index the activities table"
    Then the texts of "#agent-session .field > .f:text-is('Index it started with'), #agent-session .field > .f:text-is('Searches')" are:
      | Index it started with |
      | Searches              |
    And the text of "#agent-session .field:has(> .f:text-is('Searches')) .hint" is "None."

  Scenario: A search shows its time, query, filter pills and count, and each hit in full
    Given I file the global memory "hanami" described "Hanami notes"
    And I add the gotcha "Run specs through mise" to "hanami"
    And I add the gotcha "Run lint through mise" to "hanami"
    And the agent starts the session "Index the activities table"
    And the agent searches memory for "mise" with:
      | repo  | aaronmallen/blog |
      | scope | global           |
    And I note the ids of "hanami"
    When I open the session "Index the activities table"
    Then the texts of "#agent-session .field:has(> .f:text-is('Searches')) .agent-search-head > span" are:
      | {clock}          |
      | “mise”           |
      | aaronmallen/blog |
      | global           |
      | 2 facts          |
    And the texts of "#agent-session .field:has(> .f:text-is('Searches')) .agent-change-text" are:
      | Run specs through mise |
      | Run lint through mise  |
    And the page counts 2 of "#agent-session .field:has(> .f:text-is('Searches')) a[href='/admin/agents/memories/{file}']:has-text('hanami.md')"

  Scenario: A search marks only the hits an agent wrote
    Given I file the global memory "hanami" described "Hanami notes"
    And I add the gotcha "Run specs through mise" to "hanami"
    And the agent adds the gotcha "An agent wrote this" to "hanami"
    And the agent starts the session "Index the activities table"
    And the agent searches memory for "mise"
    And the agent searches memory for "agent"
    When I open the session "Index the activities table"
    Then the page counts 1 of "#agent-session .field:has(> .f:text-is('Searches')) .agent-change-text .agent-mark"
    And the page has "#agent-session .field:has(> .f:text-is('Searches')) .agent-change-text:has-text('An agent wrote this') .agent-mark"

  Scenario: A hit whose fact was removed later keeps its text and says so
    Given I file the global memory "hanami" described "Hanami notes"
    And I add the gotcha "Run specs through mise" to "hanami"
    And I add the gotcha "Run lint through mise" to "hanami"
    And the agent starts the session "Index the activities table"
    And the agent searches memory for "mise"
    When I remove "Run lint through mise" from "hanami"
    And I open the session "Index the activities table"
    Then the texts of "#agent-session .field:has(> .f:text-is('Searches')) .agent-change-text" are:
      | Run specs through mise |
      | Run lint through mise  |
    And the texts of "#agent-session .field:has(> .f:text-is('Searches')) .agent-change > .meta" are:
      | hanami.md                         |
      | hanami.md · fact since removed |

  Scenario: Hits in a deleted file stay without a link
    Given I file the global memory "hanami" described "Hanami notes"
    And I add the gotcha "Run specs through mise" to "hanami"
    And I add the gotcha "Run lint through mise" to "hanami"
    And the agent starts the session "Index the activities table"
    And the agent searches memory for "mise"
    When I delete the memory file "hanami"
    And I open the session "Index the activities table"
    Then the texts of "#agent-session .field:has(> .f:text-is('Searches')) span.agent-change > .meta" are:
      | a deleted file |
      | a deleted file |
    And the page has no "#agent-session .field:has(> .f:text-is('Searches')) a:has-text('a deleted file')"

  Scenario: An empty search says no filters and that no facts matched
    Given the agent starts the session "Index the activities table"
    And the agent searches memory for "nothing"
    When I open the session "Index the activities table"
    Then the text of "#agent-session .agent-search-head" holds "no filters"
    And the text of "#agent-session .field:has(> .f:text-is('Searches'))" holds "0 facts"
    And the text of "#agent-session .field:has(> .f:text-is('Searches')) .hint" matches "^No facts matched"

  Scenario: A search pills a project and a task by id
    Given the project "The blog" in the repo "aaronmallen/blog"
    And the agent starts the session "Index the activities table"
    And I note the ids of "nothing"
    And the agent searches memory for "mise" with:
      | project_id | {project1}                 |
      | task       | Index the activities table |
    When I open the session "Index the activities table"
    Then the texts of "#agent-session .field:has(> .f:text-is('Searches')) .pill" are:
      | project {project1} |
      | task {task1}       |

  Scenario: Files read follow Searches, show each read with repeats, and keep a deleted file's read
    Given I file the global memory "hanami" described "Hanami notes"
    And I file the global memory "deploys" described "Notes"
    And the agent starts the session "Index the activities table"
    And the agent reads "hanami" in its session
    And the agent reads "hanami" in its session
    And the agent reads "deploys" in its session
    And I note the ids of "hanami"
    When I delete the memory file "deploys"
    And I open the session "Index the activities table"
    Then the texts of "#agent-session .field > .f" are:
      | Index it started with |
      | Searches              |
      | Files read            |
      | Memory it changed     |
      | Artifacts it wrote    |
      | Tags                  |
    And the texts of "#agent-session .field:has(> .f:text-is('Files read')) .agent-read" are:
      | {clock} global hanami.md      |
      | {clock} global hanami.md      |
      | {clock} a deleted file        |
    And the page counts 2 of "#agent-session .field:has(> .f:text-is('Files read')) a[href='/admin/agents/memories/{file}']"
    And the page has no "#agent-session .field:has(> .f:text-is('Files read')) a:has-text('a deleted file')"

  Scenario: Files read says the index and searches were enough when it read none
    Given the agent starts the session "Index the activities table"
    When I open the session "Index the activities table"
    Then the text of "#agent-session .field:has(> .f:text-is('Files read')) .hint" is "None. The index and searches were enough."

  Scenario: Today's Agents card counts sessions, changes and artifacts and links each screen
    Given the agent starts the session "Yesterday's run"
    And the agent ends its session
    And the session "Yesterday's run" started 1 day ago and ran 1 minutes
    And the agent starts the session "Today's run"
    And the agent files the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    And the agent writes the plan "Index plan"
    And I file the global memory "owner-notes" described "Notes"
    When I visit the admin
    Then the text of ".card:has(.card-title:text-is('Agents')) .today-line:has-text('Sessions')" holds "Sessions1 today"
    And the text of ".card:has(.card-title:text-is('Agents')) .today-line:has-text('Memory')" holds "Memory2 changes today"
    And the text of ".card:has(.card-title:text-is('Agents')) .today-line:has-text('Artifacts')" holds "Artifacts1 written today"
    And the text of ".card:has(.card-title:text-is('Agents')) .pill" holds "1 running"
    And the texts of ".card:has(.card-title:text-is('Agents')) a.today-line" are:
      | Sessions1 today          |
      | Memory2 changes today    |
      | Artifacts1 written today |
    And ".card:has(.card-title:text-is('Agents')) a.today-line:has-text('Sessions')" has the "href" "/admin/agents/sessions"
    And ".card:has(.card-title:text-is('Agents')) a.today-line:has-text('Memory')" has the "href" "/admin/agents/memories"
    And ".card:has(.card-title:text-is('Agents')) a.today-line:has-text('Artifacts')" has the "href" "/admin/agents/artifacts"

  Scenario: Today's Agents card lists the three newest artifacts an agent wrote today, linked
    Given the agent writes the plan "Oldest"
    And the agent writes the plan "Older"
    And the agent writes the plan "Middle"
    And the agent writes the plan "Newest"
    And the agent writes the plan "Yesterday's plan"
    And I write the notes "Owner's notes" with the body "Body"
    And the database runs "UPDATE artifact_versions SET created_at = now() - interval '2 days' WHERE artifact_id = (SELECT id FROM artifacts WHERE title = 'Yesterday''s plan')"
    When I visit the admin
    Then the texts of ".card:has(.card-title:text-is('Agents')) .li-title" are:
      | Newest |
      | Middle |
      | Older  |
    And ".card:has(.card-title:text-is('Agents')) a:has-text('Newest')" has the "href" "/admin/agents/artifacts/4"

  Scenario: Today's Agents card shows each artifact's type, version, author and time, and no list without one
    When I visit the admin
    Then the page has no ".card:has(.card-title:text-is('Agents')) .li"
    Given the agent writes the spec "Index spec"
    When I visit the admin
    Then the page has ".card:has(.card-title:text-is('Agents')) .task-meta .task-mark.violet:has-text('spec') i.fa-ruler-combined"
    And the text of ".card:has(.card-title:text-is('Agents')) .task-meta" holds "v1"
    And the text of ".card:has(.card-title:text-is('Agents')) .task-meta" holds "Anthropic claude-opus-5-5"
