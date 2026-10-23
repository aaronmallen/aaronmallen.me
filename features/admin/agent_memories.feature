Feature: Admin agent memories
  The memories screen lists, searches and edits the memory files agents read, with each change in a history.

  Background:
    Given I am signed in to the admin
    And the project "Blog"
    And the project "Other"
    And the in_progress task "Index the activities table"

  Scenario: The list groups files by scope under the Agents pill, with counts, icons and notes
    Given I file the global memory "preferences" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "preferences"
    And I file the project memory "hanami" for "Blog" described "Notes"
    And I file the project memory "deploys" for "Blog" described "Notes"
    And I file the task memory "index" for "Index the activities table" described "Notes"
    And I file the project memory "other" for "Other" described "Notes"
    When I visit "/admin/agents/memories"
    Then "a.pill-nav-link[aria-current='page']" has the "href" "/admin/agents/memories"
    And the text of ".screen-tabs a[aria-current='page']" holds "memories"
    And the text of "h1.page-head-title" is "Agents"
    And the texts of "a.screen-tab" are:
      | memories 1 fact |
      | artifacts 0     |
      | sessions 0 today |
    And the texts of ".search-kinds a.search-kind" are:
      | All · 5      |
      | Global · 1   |
      | Projects · 3 |
      | Tasks · 1    |
    And the text of ".card-title" is "Global"
    And the page has ".card-title:has-text('Project · Blog')"
    And the page has ".card-title:has-text('Project · Other')"
    And the page has ".card-title:has-text('Task · Index the activities table')"
    And the page has ".card:has(.card-title:text-is('Global')) .card-title i.fa-globe.memory-scope-icon"
    And the page has ".card:has(.card-title:has-text('Project · Blog')) .card-title i.fa-cube"
    And the page has ".card:has(.card-title:has-text('Task · Index')) .card-title i.fa-list-check"
    And the text of ".card:has(.card-title:has-text('Project · Blog'))" holds "listed for sessions on this project or in its repo"
    And the text of ".page-head-sub" holds "1 fact in 5 files. 1 change by an agent today."
    And the page has no axe breaches in light or dark

  Scenario: The groups run global first, then projects, then tasks
    Given I file the task memory "index" for "Index the activities table" described "Notes"
    And I file the project memory "hanami" for "Blog" described "Notes"
    And I file the global memory "preferences" described "Notes"
    When I visit "/admin/agents/memories"
    Then the texts of "main .card-title:not(:has-text('index lists'))" are:
      | Global                            |
      | Project · Blog                    |
      | Task · Index the activities table |

  Scenario: Filtering by scope lists only that scope's files
    Given I file the global memory "preferences" described "Notes"
    And I file the project memory "hanami" for "Blog" described "Notes"
    And I file the project memory "deploys" for "Blog" described "Notes"
    And I file the project memory "other" for "Other" described "Notes"
    When I visit "/admin/agents/memories?scope=project"
    Then the texts of ".li-title" are:
      | deploys.md |
      | hanami.md  |
      | other.md   |
    And the text of ".search-kinds a.search-kind[aria-current='page']" is "Projects · 3"

  Scenario: Searching finds fact text and shows the facts it found, or says nothing matches
    Given I file the global memory "preferences" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "preferences"
    And I file the project memory "hanami" for "Blog" described "Notes"
    When I visit "/admin/agents/memories?query=through+MISE"
    Then the texts of ".li-title" are:
      | preferences.md |
    And the text of ".memory-hit" holds "Run specs through mise"
    When I visit "/admin/agents/memories?query=zeppelin"
    Then the text of ".empty" holds "No file or fact matches “zeppelin”."

  Scenario: The index card lists what a session on the chosen project lists, with counts and descriptions
    Given I file the global memory "preferences" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "preferences"
    And I file the project memory "hanami" for "Blog" described "Notes"
    And I file the project memory "deploys" for "Blog" described "Notes"
    And I file the project memory "other" for "Other" described "Notes"
    When I visit the index of memories for the project "Blog"
    Then the texts of ".card:has-text('What a session') a.memory-line .memory-line-path" are:
      | global preferences.md |
      | project deploys.md    |
      | project hanami.md     |
    And the text of ".card:has-text('What a session') a.memory-line:has-text('preferences') .memory-line-head" holds "1 fact"
    And the text of ".card:has-text('What a session') a.memory-line .memory-description" is "Notes"
    And the text of "main" holds "3 lines · 1 fact behind them"

  Scenario: The project picker lists the projects and picks the first when none is chosen
    When I visit "/admin/agents/memories"
    Then the "Working in" picker offers "Blog, Other" with "Blog" picked

  Scenario: The lede says when no agent changed memory today
    Given I file the global memory "preferences" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "preferences"
    And the database runs "UPDATE memory_events SET created_at = now() - interval '2 days' WHERE agent IS NOT NULL"
    When I visit "/admin/agents/memories"
    Then the text of ".page-head-sub" holds "No agent changes today."

  Scenario: Each row shows its description and who changed it last, and marks an agent's description
    Given I file the global memory "preferences" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "preferences"
    And I file the project memory "hanami" for "Blog" described "Notes"
    And the agent files the global memory "agent" described "Mine"
    When I visit "/admin/agents/memories?scope=global"
    Then the text of ".li:has-text('preferences.md') .memory-description" is "Notes"
    And the text of ".li:has-text('preferences.md') .li-sub" matches "1 fact · updated .+ by Anthropic claude-opus-5-5$"
    And the page has ".li:has-text('agent.md') .memory-description .agent-mark[title='Written by Anthropic claude-opus-5-5. Untrusted.'] i.fa-robot[aria-label='Agent-written, untrusted']"
    And the page has no ".li:has-text('preferences.md') .agent-mark"
    When I visit "/admin/agents/memories?scope=project"
    Then the text of ".li:has-text('hanami.md') .li-sub" matches "by you$"

  Scenario: The scope choices offer any open task but no closed one
    Given the open task "Write the release notes"
    And the canceled task "Drop the old feed"
    When I visit "/admin/agents/memories"
    Then the page has "option:has-text('Task · Write the release notes')"
    And the page has no "option:has-text('Task · Drop the old feed')"

  Scenario: The new file form reads File, Scope, Description, Create and Cancel, and Cancel keeps the view
    When I visit "/admin/agents/memories?scope=task&query=mise"
    Then the texts of "form.memory-new-form label, form.memory-new-form button, form.memory-new-form a.bt" are:
      | File        |
      | Scope       |
      | Description |
      | Create      |
      | Cancel      |
    And "form.memory-new-form a.bt.gh" has the "href" "/admin/agents/memories?scope=task&query=mise"
    And the text of "details.memory-new label[for$='scope'], details.memory-new label:text-is('Scope')" is "Scope"

  Scenario: A new file is made by the owner and opens
    When I file the global memory "testing" described "Tests"
    Then the answer sends me to "/admin/agents/memories/1"
    And the memory events of "testing" are:
      | create |  | you |
    And the database answers "testing.md, Tests, true" for:
      """
      SELECT path, description, description_agent IS NULL AS owned FROM memory_files
      """

  Scenario Outline: A new file with <what> is refused and the form stays open
    Given I file the global memory "testing" described "Notes"
    When I post to "/admin/agents/memories" with:
      | memory_file[path]        | <path>        |
      | memory_file[description] | <description> |
      | memory_file[scope]       | <scope>       |
    Then the answer is 422
    And the answer shows "<error>"
    And the answer shows "memory-new\" open"

    Examples:
      | what                  | path     | description | scope       | error                                        |
      | a bad path            | bad path! | Notes      | global      | Use letters, digits                          |
      | a blank description   | other    |             | global      | Describe the file in one line.               |
      | a path the scope holds | testing | Notes       | global      | A file in this scope already has this path.  |
      | a task that is gone   | other    | Notes       | task:999999 | That record is gone                          |
      | no scope              | other    | Notes       |             | Pick a scope.                                |

  Scenario: A file shows its description once, its scope and fact count, and its facts with who wrote them
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    And I add the convention "Use jj" to "hanami"
    When I open the memory file "hanami"
    Then the page has no ".page-head:has-text('Notes')"
    And the page counts 1 of ".memory-description:has-text('Notes')"
    And the text of ".page-head-kicker" holds "Global"
    And the page has ".page-head-kicker i.fa-globe"
    And the text of ".page-head-sub" holds "Listed in the index for every session"
    And the text of ".memory-fact:has-text('Run specs through mise') .pill" is "gotcha"
    And the text of ".memory-fact:has-text('Run specs through mise')" holds "Anthropic claude-opus-5-5"
    And the page has ".memory-fact:has-text('Run specs through mise') .memory-fact-text .agent-mark i.fa-robot"
    And the page has no ".memory-fact:has-text('Use jj') .memory-fact-text .agent-mark"
    And the page has no axe breaches in light or dark

  Scenario: A file lists its facts in one list in fact type order and escapes what agents wrote
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the context "A context" to "hanami"
    And the agent adds the gotcha "A gotcha" to "hanami"
    And the agent adds the preference "<script>alert(1)</script>" to "hanami"
    When I open the memory file "hanami"
    Then the page counts 1 of "ul.memory-fact-list"
    And the texts of ".memory-fact .pill" are:
      | preference |
      | gotcha     |
      | context    |
    And the text of ".memory-fact:has(.pill:text-is('preference')) .memory-fact-text" holds "<script>alert(1)</script>"

  Scenario: A project file names the sessions that list it, and the old loaded view shows the facts
    Given I file the project memory "hanami" for "Blog" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    When I open the memory file "hanami"
    Then the text of "main" holds "Listed in the index for sessions on Blog or in its repo"
    When I open the memory file "hanami" with "view=loaded"
    Then the page has ".memory-fact:has-text('Run specs through mise')"
    And the page has no "main pre"
    And the text of "main" does not hold "as loaded"

  Scenario: A file that does not exist is not found
    When I send GET "/admin/agents/memories/999999"
    Then the answer is 404

  Scenario: The index line shows the path, scope, fact count, description and who wrote it
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    When I open the memory file "hanami"
    Then the texts of ".memory-index-head .memory-index-path, .memory-index-head .pill, .memory-index-head .meta" are:
      | hanami.md |
      | global    |
      | 1 fact    |
    And the page has ".memory-index-head .pill i.fa-globe"
    And the text of ".memory-index-description" holds "Notes"
    And the text of ".card:has-text('what a session starts with')" holds "description by you"

  Scenario: An agent's description names and marks the agent
    Given I file the global memory "hanami" described "Notes"
    And the agent describes "hanami" as "How we test"
    When I open the memory file "hanami"
    Then the text of ".card:has-text('what a session starts with')" holds "description by Anthropic claude-opus-5-5"
    And the page has ".card:has-text('what a session starts with') .memory-description .agent-mark i.fa-robot"

  Scenario: Changing the description saves it, says so and writes a history entry with both texts
    Given I file the global memory "hanami" described "Notes"
    When I describe "hanami" as "How we test"
    And I follow the answer
    Then the page's toast reads "Description saved"
    And the memory events of "hanami" are:
      | create   |             | you |
      | describe | How we test | you |
    And the database answers "How we test, Notes" for:
      """
      SELECT text, was_text FROM memory_events WHERE op = 'describe'
      """
    When I open the memory file "hanami"
    Then the text of ".memory-event:first-child .memory-event-what" matches "^you changed the description “Notes” to “How we test”"

  Scenario: Reverting a describe puts the old description back and names what it undid
    Given I file the global memory "hanami" described "Notes"
    And the agent describes "hanami" as "How we test"
    When I revert the latest change to "hanami"
    Then the database answers "Notes, true" for:
      """
      SELECT description, description_agent IS NULL AS owned FROM memory_files
      """
    And the database answers "revert, Notes, How we test" for:
      """
      SELECT op, text, was_text FROM memory_events ORDER BY id DESC LIMIT 1
      """
    When I open the memory file "hanami"
    Then the text of ".memory-event:first-child" holds "reverted a description change"

  Scenario: Only the latest describe offers a revert
    Given I file the global memory "hanami" described "Notes"
    And I describe "hanami" as "Take 0"
    And I describe "hanami" as "Take 1"
    When I open the memory file "hanami"
    And I note the ids of "hanami"
    Then the page has no "#memory-event-{event2} form"
    And the text of "#memory-event-{event3} form button" is "revert"

  Scenario Outline: A description that is <what> is refused and opens the form
    Given I file the global memory "hanami" described "Notes"
    When I post to "/admin/agents/memories/1/description" with:
      | memory_file[description] | <description> |
    Then the answer is 422
    And the answer shows "<error>"
    And the answer shows "memory-edit\" open"

    Examples:
      | what           | description | error                             |
      | blank          |             | Describe the file in one line.    |
      | over two lines | One\u000aTwo | Keep the description to one line. |

  Scenario: The owner adds, edits and removes a fact, leaving the file empty
    Given I file the global memory "hanami" described "Notes"
    When I add the convention "Use jj" to "hanami"
    And I change the convention "Use jj" in "hanami" to "Use jj, not git"
    And I remove "Use jj, not git" from "hanami"
    Then the memory events of "hanami" are:
      | create |                 | you |
      | add    | Use jj          | you |
      | edit   | Use jj, not git | you |
      | remove | Use jj, not git | you |
    And "hanami" holds no facts

  Scenario: Reverting a removal brings the fact back
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    When I remove "Run specs through mise" from "hanami"
    And I revert the latest change to "hanami"
    Then "hanami" holds the facts "Run specs through mise"

  Scenario: Reverting an edit brings back the old text and the agent that wrote it
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    When I change the gotcha "Run specs through mise" in "hanami" to "Run specs with rspec"
    And I revert the latest change to "hanami"
    Then the database answers "Run specs through mise, claude-code, claude-opus-5-5" for:
      """
      SELECT text, agent, model FROM memory_facts WHERE removed_at IS NULL
      """
    And the database answers "revert, you" for:
      """
      SELECT op, coalesce(agent, 'you') AS who FROM memory_events ORDER BY id DESC LIMIT 1
      """

  Scenario: Reverting an add drops the fact from the next session's memory
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    When I revert the latest change to "hanami"
    And the agent starts the session "Spike"
    Then "hanami" holds no facts
    And the session's loaded memory holds no facts

  Scenario: Reverting a change a later change touched says so
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    And the agent changes "Run specs through mise" in "hanami" to "Use mise"
    When I revert change 2 of "hanami"
    And I follow the answer
    Then the page's toast reads "A later change came after this one · revert that one first"

  Scenario: Fact text of any length adds and edits
    Given I file the global memory "hanami" described "Notes"
    When I add a gotcha of 5000 "a"s to "hanami"
    And I change the gotcha of 5000 "a"s in "hanami" to 6000 "b"s
    Then the database answers "6000" for:
      """
      SELECT length(text) FROM memory_facts
      """

  Scenario: A blank fact is refused and a blank edit opens that fact's form
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    When I post to "/admin/agents/memories/1/facts" with:
      | fact[type] | gotcha |
      | fact[text] |        |
    Then the answer is 422
    And the answer shows "id=\"memory-new-fact-text-error\""
    And the answer shows "Write the fact first."
    When I change the gotcha "Run specs through mise" in "hanami" to ""
    Then the answer shows "details class=\"memory-edit\" open"

  Scenario: Only each fact's latest change offers a revert, and a reverted entry says so
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    And the agent changes "Run specs through mise" in "hanami" to "Use mise"
    And the agent adds the gotcha "Use jj" to "hanami"
    When I revert the latest change to "hanami"
    And I open the memory file "hanami"
    And I note the ids of "hanami"
    Then the page has no "#memory-event-{event2} form"
    And the text of "#memory-event-{event3} form button" is "revert"
    And the text of "#memory-event-{event4} .meta" holds "reverted"

  Scenario: Each history entry links to its session
    Given I file the global memory "hanami" described "Notes"
    And the agent starts the session "Spike"
    And the agent adds the gotcha "Use mise" to "hanami"
    When I open the memory file "hanami"
    Then ".card:has-text('History') a:text-is('session')" has the "href" "/admin/agents/sessions?session={session}"

  Scenario: The history names who made each change, as who, what and the quoted text
    Given I file the global memory "hanami" described "Notes"
    And the agent adds the gotcha "Run specs through mise" to "hanami"
    And the agent changes "Run specs through mise" in "hanami" to "Use mise"
    And I remove "Use mise" from "hanami"
    When I open the memory file "hanami"
    Then the texts of ".card:has-text('History') .memory-event-what" are:
      | you removed “Use mise”revert                                             |
      | Anthropic claude-opus-5-5 changed “Run specs through mise” to “Use mise” |
      | Anthropic claude-opus-5-5 added “Run specs through mise”                 |
      | you created the file                                                     |
    And the texts of ".card:has-text('History') .memory-event-what strong" are:
      | you                       |
      | Anthropic claude-opus-5-5 |
      | Anthropic claude-opus-5-5 |
      | you                       |

  Scenario: Moving a file to another scope writes a scope entry, and keeping the scope writes none
    Given I file the global memory "hanami" described "Notes"
    And I file the global memory "deploys" described "Notes"
    When I move "hanami" to the project "Blog"
    And I move "deploys" to the global scope
    Then the database answers "hanami.md, project, Blog" for:
      """
      SELECT f.path, f.scope, p.name FROM memory_files f JOIN projects p ON p.id = f.project_id
      """
    And the memory events of "hanami" are:
      | create |  | you |
      | scope  |  | you |
    And the memory events of "deploys" are:
      | create |  | you |

  Scenario: Moving a file to a scope that holds its path is refused
    Given I file the global memory "hanami" described "Notes"
    And I file the project memory "hanami" for "Blog" described "Notes"
    When I move "hanami" to the project "Blog"
    Then the answer shows "That scope already has a file with this path."

  Scenario: Deleting a file asks first in the index's words, then drops it and says so
    Given I file the global memory "hanami" described "Notes"
    When I open the memory file "hanami"
    Then "form[action$='/delete']:has-text('Delete file')" has the "data-confirm" "Delete hanami.md? It drops out of every session's index, and agents can no longer read or search it."
    When I delete the memory file "hanami"
    Then the answer sends me to "/admin/agents/memories"
    And the table memory_files holds 0 rows
    When I follow the answer
    Then the page's toast reads "Memory file deleted · agents can no longer read it"

  Scenario: The history pages a hundred at a time, marks reverts across pages, and has an end
    Given I file the global memory "hanami" described "Notes"
    And the agent adds 100 gotchas to "hanami"
    When I revert change 2 of "hanami"
    And I note the ids of "hanami"
    And I open the memory file "hanami"
    Then the page counts 100 of ".card:has-text('History') .memory-event"
    And the text of ".card:has-text('History') .card-title" holds "102"
    And ".card:has-text('History') a[rel='next']" has the "href" "/admin/agents/memories/{file}?page=2"
    And the text of "#memory-event-{event102}" holds "reverted an addition"
    When I open the memory file "hanami" with "view=loaded"
    Then ".card:has-text('History') a[rel='next']" has the "href" "/admin/agents/memories/{file}?page=2"
    When I open the memory file "hanami" with "page=2"
    Then the texts of ".card:has-text('History') .memory-event-what strong" are:
      | Anthropic claude-opus-5-5 |
      | you                       |
    And the text of "#memory-event-{event2} .meta" holds "reverted"
    And the page has no "#memory-event-{event2} form"
    When I send GET "/admin/agents/memories/1?page=3"
    Then the answer is 404

  Scenario: A file links, lists, finds and unlinks a task
    Given I file the global memory "hanami" described "Notes"
    And I note the ids of "hanami"
    When I open the memory file "hanami" with "record_q=activities"
    Then the page has ".record-links [name='record[other_id]'][value='{task1}']"
    When I post to "/admin/agents/memories/{file}/records" with:
      | record[other_kind] | task    |
      | record[other_id]   | {task1} |
    And I open the memory file "hanami"
    Then ".record-links a:has-text('Index the activities table')" has the "href" "/admin/tasks/{task1}"
    When I post to "/admin/records/memory_file/{file}/links/task/{task1}/delete"
    Then the table record_links holds 0 rows

  Scenario: A task file draws its task without a remove button, and keeps it
    Given I file the task memory "index" for "Index the activities table" described "Notes"
    And I note the ids of "index"
    When I open the memory file "index"
    Then the page has ".record-links a:has-text('Index the activities table')"
    And the page has no ".record-links .record-link-row form"
    When I post to "/admin/records/memory_file/{file}/links/task/{task1}/delete"
    Then the answer sends me to "/admin/agents/memories/{file}"
    When I follow the answer
    Then the page's toast reads "Link kept · this memory file belongs to that record, so change its scope instead"

  Scenario: Today, a session and a task link into memory
    Given I file the global memory "hanami" described "Notes"
    And I file the task memory "index" for "Index the activities table" described "Notes"
    And the agent starts the session "Spike"
    And the agent reads "hanami" in its session
    And the agent adds the gotcha "Use mise" to "hanami"
    And I note the ids of "hanami"
    When I visit the admin
    Then ".today-line:has-text('Memory')" has the "href" "/admin/agents/memories"
    When I visit "/admin/agents/sessions?session={session}"
    Then the texts of "#agent-session a[href='/admin/agents/memories/{file}']" are:
      | global hanami.md0 factsNotes |
      | global hanami.md             |
      | added to hanami.mdUse mise   |
    When I visit "/admin/tasks/{task1}"
    Then the page has "a:has-text('index.md')"
