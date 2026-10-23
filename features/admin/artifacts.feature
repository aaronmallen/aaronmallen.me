Feature: Admin artifacts
  The artifacts screen lists, searches, reads, edits and restores the numbered documents agents and the owner write.

  Background:
    Given I am signed in to the admin

  Scenario: The list sorts by the latest version and names each row's type, version, author and tags
    Given I write the plan "Plan the index" with the body "Add an index"
    And I write the notes "Notes on caching" with the body "Use Redis"
    And I save "Plan the index" with:
      | tags | db, perf |
      | body | v2       |
    And version 1 of "Plan the index" dates from "5 minutes ago"
    And version 1 of "Notes on caching" dates from "2 minutes ago"
    And version 2 of "Plan the index" dates from "1 minute ago"
    And I note the ids of "nothing"
    When I visit "/admin/agents/artifacts"
    Then the text of "a.pill-nav-link[aria-current='page']" holds "Agents"
    And the text of "h1.page-head-title" is "Agents"
    And the texts of "a.screen-tab" are:
      | memories 0 facts |
      | artifacts 2      |
      | sessions 0 today |
    And the texts of ".artifact-row-title" are:
      | Plan the index   |
      | Notes on caching |
    And the text of ".artifact-row:has-text('Plan the index') .artifact-row-meta" matches "^planv2.+ by you#db#perf$"
    And the text of ".artifact-row:has-text('Notes on caching') .artifact-row-meta" matches "^notesv1.+ by you$"
    And the texts of ".artifact-row > .record-key:first-child" are:
      | #1 |
      | #2 |
    And the page counts 1 of ".artifact-row-meta .tone-text.blue i.fa-route"
    And the page counts 1 of ".artifact-row-meta .tone-text.sand i.fa-note-sticky"
    And the texts of ".search-kind" are:
      | All 2        |
      | plan 1       |
      | spec 0       |
      | research 0   |
      | handoff 0    |
      | notes 1      |
      | review 0     |
      | postmortem 0 |
      | other 0      |
    And the page has ".search-kind i.fa-route.text-mk-blue-text"
    And the page has ".search-kind i.fa-file:not([class*='text-mk'])"
    And the text of ".page-head-sub" holds "2 artifacts, 2 updated this week."
    And "a:has-text('New artifact')" has the "href" "/admin/agents/artifacts/new"
    And the page has no axe breaches in light or dark

  Scenario: Each tag takes the colour of the private tag it carries
    Given the agent writes the plan "Plan the index" tagged "db"
    And the database runs "UPDATE tags SET color = 'mk-green' WHERE name = 'db' AND scope = 'private'"
    And the table tags holds:
      | name | color     | scope  |
      | db   | mk-orange | public |
    When I visit "/admin/agents/artifacts"
    Then the text of ".artifact-row-meta .tag.green" is "#db"

  Scenario: A project tag links to its project's tag page, and the row counts its links
    Given the project "BLOG"
    And the task "Index the activities table"
    And the agent writes the plan "Plan the index" tagged ""
    When I link "Plan the index" to the project "BLOG"
    And I link "Plan the index" to the task "Index the activities table"
    And the agent tags "Plan the index" with "db"
    And I visit "/admin/agents/artifacts"
    Then "a:text-is('#db')" has the "href" "/admin/projects/BLOG/tags/db"
    And the text of ".artifact-row-meta span:has(> i.fa-link)" holds "2 links"

  Scenario: Each row dates and credits its current version
    Given I write the notes "Notes on caching" with the body "Use Redis"
    And the agent revises "Notes on caching" to the body "Use Valkey"
    And version 2 of "Notes on caching" dates from "(TIMESTAMPTZ '2026-10-01 12:00:00+00')"
    When I visit "/admin/agents/artifacts"
    Then the text of ".artifact-row-meta" matches "^notesv2Oct 1, 2026 by Anthropic claude-opus-5-5$"

  Scenario: Filtering by type and searching the body and the tags narrow the list, and the pills keep the search
    Given the agent writes the plan "Plan the index" tagged "db"
    And I write the notes "Notes on caching" with the body "Use Redis"
    When I visit "/admin/agents/artifacts?type=notes"
    Then the texts of ".artifact-row-title" are:
      | Notes on caching |
    When I visit "/admin/agents/artifacts?search=redis"
    Then the texts of ".artifact-row-title" are:
      | Notes on caching |
    When I visit "/admin/agents/artifacts?search=db"
    Then the texts of ".artifact-row-title" are:
      | Plan the index |
    When I visit "/admin/agents/artifacts?type=notes&search=redis"
    Then "a.search-kind:has-text('notes 1')" has the "href" "/admin/agents/artifacts?type=notes&search=redis"
    And the text of ".search-kind[aria-current=page]" is "notes 1"
    And "a.search-kind:has-text('All 2')" has the "href" "/admin/agents/artifacts?search=redis"
    When I visit "/admin/agents/artifacts?search=nothing+like+it"
    Then the page has ".empty"

  Scenario: With no artifact the list says so
    When I visit "/admin/agents/artifacts"
    Then the page has ".empty"

  Scenario: The new artifact form posts without script and creates an owner's artifact that opens
    When I visit "/admin/agents/artifacts/new"
    Then the page has "form[method='post'][action='/admin/agents/artifacts'] textarea[name='artifact[body]']"
    And the page has "select[name='artifact[type]'] option[selected][value='plan']"
    And the page has ".edit-split .preview"
    And the text of ".page-head-actions button[form=artifact-form]" is "Create artifact"
    And the page has no axe breaches in light or dark
    When I post to "/admin/agents/artifacts" with:
      | artifact[title] | My plan |
      | artifact[type]  | spec    |
      | artifact[tags]  | site    |
      | artifact[body]  | # Hi    |
    Then the answer sends me to "/admin/agents/artifacts/1"
    And the versions of "My plan" are "v1 you"
    And the database answers "site" for:
      """
      SELECT t.name FROM artifact_tags at JOIN tags t ON t.id = at.tag_id
      """

  Scenario: A blank body is refused and keeps what was typed
    When I post to "/admin/agents/artifacts" with:
      | artifact[title] | My plan |
      | artifact[type]  | spec    |
      | artifact[tags]  |         |
      | artifact[body]  |         |
    Then the answer is 422
    And the answer shows "id=\"artifact-body-error\""
    And the answer shows "value=\"My plan\""

  Scenario: The page renders agent markdown sanitized, with its type, tags and creator, and no banner when current
    Given the agent writes the plan "Plan the index" with the body "# Plan\n\n**bold** <script>alert(1)</script>"
    And the table tags holds:
      | name | color   | scope   |
      | perf | mk-pink | private |
    And the agent tags "Plan the index" with "perf"
    And the agent revises "Plan the index" to the body "Next"
    When I visit "/admin/agents/artifacts/1?version=1"
    Then the text of ".markdown-body strong" is "bold"
    And the page has no ".markdown-body script"
    When I open the artifact "Plan the index"
    Then the page counts 1 of ".page-head-actions .tone-text.blue i.fa-route"
    And the text of ".read-meta .tag.pink" is "#perf"
    And the text of ".read-meta" matches "^Created .+ by Anthropic claude-opus-5-5"
    And the page has no ".post-banner"
    And the page has no axe breaches in light or dark

  Scenario: The page lists versions newest first with the author and note
    Given the agent writes the plan "Plan the index" with the body "Add an index"
    When I save "Plan the index" with:
      | body | Next    |
      | note | Tidied  |
    And I open the artifact "Plan the index"
    Then the text of ".artifact-version >> nth=0" matches "^v2you · .+ · currentTidied$"
    And the text of ".artifact-version >> nth=1" matches "^v1Anthropic claude-opus-5-5 · .+$"

  Scenario: An artifact that does not exist is not found
    When I send GET "/admin/agents/artifacts/999999"
    Then the answer is 404

  Scenario: An old version shows under a banner and restores as a new version
    Given the agent writes the plan "Plan the index" with the body "First body"
    And the agent revises "Plan the index" to the body "Second body"
    When I visit "/admin/agents/artifacts/1?version=1"
    Then the text of ".markdown-body" holds "First body"
    And the text of ".post-banner" holds "You are reading v1 of 2"
    And ".post-banner form" has the "action" "/admin/agents/artifacts/1/versions/1/restore"
    When I post to "/admin/agents/artifacts/1/versions/1/restore"
    Then the answer sends me to "/admin/agents/artifacts/1"
    And the versions of "Plan the index" are "v1 claude-code, v2 claude-code, v3 you Restored version 1"
    And the database answers "First body" for:
      """
      SELECT body FROM artifact_versions WHERE number = 3
      """

  Scenario: The editor saves from the head as the next version and fills the latest body
    Given the agent writes the plan "Plan the index" with the body "Add an index"
    And the agent revises "Plan the index" to the body "Next"
    When I visit "/admin/agents/artifacts/1/edit"
    Then the text of ".page-head-actions button[type=submit][form=artifact-form]" is "Save as v3"
    And the page has "form#artifact-form[action='/admin/agents/artifacts/1']"
    And "a:text-is('Cancel')" has the "href" "/admin/agents/artifacts/1"
    And the page has "textarea[name='artifact[body]']:text-is('Next')"
    And the page has no axe breaches in light or dark

  Scenario: Saving a body change adds a version with its note
    Given the agent writes the plan "Plan the index" with the body "Add an index"
    When I save "Plan the index" with:
      | body | Add two indexes |
      | note | Split the index |
    Then the answer sends me to "/admin/agents/artifacts/1"
    And the versions of "Plan the index" are "v1 claude-code, v2 you Split the index"

  Scenario: Saving only a new title adds no version and clears the agent's mark on it
    Given the agent writes the plan "Plan the index" with the body "Add an index"
    When I save "Plan the index" with:
      | title | Index plan |
    Then the versions of "Index plan" are "v1 claude-code"
    And the database answers "Index plan, true" for:
      """
      SELECT title, title_agent IS NULL AS owned FROM artifacts
      """

  Scenario: A note over the cap is refused
    Given the agent writes the plan "Plan the index" with the body "Add an index"
    When I save "Plan the index" with a note of 201 characters
    Then the answer shows "id=\"artifact-note-error\""
    And the answer shows "200 characters"

  Scenario: Record links show, link and unlink with plain forms, and the task links back
    Given the task "Index the activities table"
    And the agent writes the plan "Plan the index" with the body "Add an index"
    And I note the ids of "nothing"
    When I link "Plan the index" to the task "Index the activities table"
    And I open the artifact "Plan the index"
    Then ".record-links a:has-text('Index the activities table')" has the "href" "/admin/tasks/{task1}"
    When I visit "/admin/tasks/{task1}"
    Then "a:has-text('Plan the index')" has the "href" "/admin/agents/artifacts/{artifact}"
    When I post to "/admin/records/artifact/{artifact}/links/task/{task1}/delete"
    Then the table record_links holds 0 rows

  Scenario: Deleting an artifact drops every version
    Given the agent writes the plan "Plan the index" with the body "Add an index"
    And the agent revises "Plan the index" to the body "Next"
    When I post to "/admin/agents/artifacts/1/delete"
    Then the answer sends me to "/admin/agents/artifacts"
    And the table artifacts holds 0 rows
    And the table artifact_versions holds 0 rows

  Scenario: The session drawer links each artifact the session wrote to its version
    Given the agent starts the session "Index"
    And the agent writes the plan "Plan the index" with the body "Add an index"
    When I open the session "Index"
    Then the page has "#agent-session a[href='/admin/agents/artifacts/{artifact}?version=1']"
