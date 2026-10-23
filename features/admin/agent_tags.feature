Feature: Admin agent tags
  Sessions, memory files and artifacts of a project take that project's own tags, and its tag page lists them.

  Background:
    Given I am signed in to the admin
    And the project "BLOG" in the repo "aaronmallen/blog"

  Scenario: A session takes its project's own tag from the drawer, shows it linked, and drops it
    Given the agent starts the session "Spike" with:
      | repo | aaronmallen/blog |
    When I post to "/admin/agents/sessions/{session}/tags" with:
      | tag       | perf                                     |
      | return_to | /admin/agents/sessions?session={session} |
    Then the answer sends me to "/admin/agents/sessions?session={session}"
    And the tags of the session are "perf project BLOG"
    When I visit "/admin/agents/sessions?session={session}"
    Then "#agent-session a:text-is('#perf')" has the "href" "/admin/projects/BLOG/tags/perf"
    When I post to "/admin/agents/sessions/{session}/tags/delete" with:
      | tag       | perf                                     |
      | return_to | /admin/agents/sessions?session={session} |
    Then the tags of the session are ""

  Scenario: A memory file takes its project's own tag from its page, shows it linked, and drops it
    Given the agent files the project memory "notes" for "BLOG" described "Notes"
    And I note the ids of "notes"
    When I post to "/admin/agents/memories/{file}/tags" with:
      | tag | perf |
    Then the tags of the memory file "notes" are "perf project BLOG"
    When I open the memory file "notes"
    Then "a:text-is('#perf')" has the "href" "/admin/projects/BLOG/tags/perf"
    When I post to "/admin/agents/memories/{file}/tags/delete" with:
      | tag | perf |
    Then the tags of the memory file "notes" are ""

  Scenario: An artifact linked to a project offers and saves that project's own tags
    Given the table tags holds:
      | name | color   | scope   | project_id                          |
      | perf | mk-pink | project | (SELECT id FROM projects LIMIT 1)   |
    And the agent writes the plan "Plan" with the body "Steps"
    When I link "Plan" to the project "BLOG"
    And I visit "/admin/agents/artifacts/{artifact}/edit"
    Then the tag field of the artifact form offers "perf"
    When I save "Plan" with:
      | tags | fast |
    Then the database answers "fast, BLOG" for:
      """
      SELECT t.name AS tag, p.name AS project FROM artifact_tags at JOIN tags t ON t.id = at.tag_id JOIN projects p ON p.id = t.project_id
      """

  Scenario: The project tag page lists the sessions, memory files and artifacts that carry it
    Given the agent starts the session "Spike" with:
      | repo | aaronmallen/blog |
    And the agent tags its session "perf"
    And the agent files the project memory "notes" for "BLOG" described "Notes"
    And the agent tags the memory file "notes" "perf"
    And the agent writes the plan "Plan" with the body "Steps"
    When I link "Plan" to the project "BLOG"
    And the agent tags "Plan" with "perf"
    And I visit "/admin/projects/BLOG/tags/perf"
    Then the texts of ".card:has-text('Agent sessions') .li-title" are:
      | Spike |
    And the texts of ".card:has-text('Memory files') .li-title" are:
      | notes.md |
    And the texts of ".card:has-text('Artifacts') .li-title" are:
      | Plan |
    And the page has no axe breaches in light or dark
