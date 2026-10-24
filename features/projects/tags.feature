Feature: A project's own tags
  Each project keeps its own tags in a manager on its board, and each tag has a page listing what carries it.
  The global tag screens leave project tags out.

  Background:
    Given the projects:
      | name | key  |
      | blog | BLOG |
      | pod  | POD  |
    And the tags table holds the rows:
      | name   | color   | scope   | project_id | description     |
      | bug    | mk-pink | project | 1          | something broke |
      | docs   | mk-blue | project | 1          |                 |
      | lonely | mk-blue | project | 2          |                 |

  Scenario: Signed out, adding a project tag sends me to sign in and adds nothing
    When I send the admin form "/admin/projects/1/project_tags" with a forged token and:
      | tag[name] | fresh |
    Then the database reads "0" for:
      """
      SELECT count(*) FROM tags WHERE name = 'fresh'
      """

  Scenario: The board's Tags button counts the project's tags and opens a manager of them alone
    Given I am signed in to the admin
    When I visit "/admin/projects/1"
    Then the page part "button[commandfor='project-tags']" reads "Tags2"
    And the page parts "#project-tags .project-tags-name .tag" read "#bug | #docs"
    And the page part "#project-tags .project-tags-description" holds "something broke"
    And the page parts "#project-tags .project-tags-name a.tag" have "href" set to "/admin/projects/BLOG/tags/bug | /admin/projects/BLOG/tags/docs"
    And the page has no "#project-tags[data-dialog-show]"
    When I visit "/admin/projects/1?tags=open"
    Then the page has "#project-tags[data-dialog-show]"

  Scenario: Adding a project tag stores it with its description and sends the manager back open
    Given I am signed in to the admin
    And the tags table holds the rows:
      | name | color   | scope   |
      | bug  | mk-blue | private |
    When I send the admin form "/admin/projects/2/project_tags" with:
      | tag[name]        | Bug          |
      | tag[description] | it broke too |
    Then the admin answer goes to "/admin/projects/2?tags=open"
    When I follow the admin answer
    Then the toast says "Tag added"
    And the database reads "bug, it broke too / lonely, " for:
      """
      SELECT name, coalesce(description, '') FROM tags WHERE project_id = 2 ORDER BY name
      """

  Scenario: Adding a project tag refuses a name the project holds, one that is not a slug and a blank one
    Given I am signed in to the admin
    Then the project tag form for "blog" says:
      | name       | toast                                                            |
      | bug        | Nothing saved · this project already holds that tag              |
      | not a tag! | Nothing saved · a tag takes lowercase letters, numbers and dashes |
      | " "        | Nothing added · give the tag a name first                        |
    And the database reads "2" for:
      """
      SELECT count(*) FROM tags WHERE project_id = 1
      """
    When I send the admin form "/admin/projects/999999/project_tags" with:
      | tag[name] | bug |
    Then the server answers 404

  Scenario: Editing a project tag renames, describes and recolours it, and removing one takes it away
    Given I am signed in to the admin
    When I send the admin form "/admin/projects/1/project_tags/1" with:
      | tag[name]        | defect   |
      | tag[description] | fix it   |
      | tag[color]       | mk-green |
    And I follow the admin answer
    Then the toast says "Tag saved"
    And the database reads "defect, fix it, mk-green" for:
      """
      SELECT name, description, color FROM tags WHERE id = 1
      """
    When I send the admin form "/admin/projects/1/project_tags/3" with:
      | tag[name] | defect |
    Then the server answers 404
    When I send the admin form "/admin/projects/1/project_tags/2/delete"
    And I follow the admin answer
    Then the toast says "Tag removed"
    And the database reads "defect" for:
      """
      SELECT name FROM tags WHERE project_id = 1
      """

  Scenario: The global tag screens leave project tags out
    Given I am signed in to the admin
    When I visit "/admin/settings/tagging?scope=public"
    Then the page has no ".tag-name:has-text('#bug')"
    When I visit "/admin/settings/tagging?scope=private"
    Then the page has no ".tag-name:has-text('#bug')"
    When I visit "/admin/settings/tagging?scope=project"
    Then the page has no ".tag-name:has-text('#bug')"
    When I fetch the admin page "/admin/tags/private/choices" as JSON
    Then the answer does not show "bug"

  Scenario: A project tag's page groups what carries it and nothing else
    Given I am signed in to the admin
    And a published post "Fixing the feed"
    And the tasks:
      | title                | tags |
      | A private bug        | bug  |
    And the project tasks:
      | title                | project | tags   |
      | Fix the feed         | blog    | bug    |
      | Another project's bug | pod    | bug    |
    And the database runs:
      """
      INSERT INTO journal_entries (entry_date, entry_time, body, body_html) VALUES (current_date, '09:00', 'Chased the feed bug', '<p>Chased the feed bug</p>');
      INSERT INTO decisions (title, problem) VALUES ('Drop the feed', 'Why?');
      INSERT INTO post_tags (post_id, tag_id, tag_scope) VALUES (1, 1, 'project');
      INSERT INTO journal_entry_tags (journal_entry_id, tag_id, tag_scope) VALUES (1, 1, 'project');
      INSERT INTO decision_tags (decision_id, tag_id, tag_scope) VALUES (1, 1, 'project');
      """
    When I visit "/admin/projects/BLOG/tags/bug"
    Then the page parts ".card:has-text('Posts') .li-title" read "Fixing the feed"
    And the page parts ".card:has-text('Tasks') .li-title" read "Fix the feed"
    And the page parts ".card:has-text('Journal entries') .li-title" read "Chased the feed bug"
    And the page parts ".card:has-text('Decisions') .li-title" read "Drop the feed"
    And the page has no ".card:has-text('Projects')"
    And the page part ".card:has-text('Tasks') a:text-is('#bug')" has "href" set to "/admin/projects/BLOG/tags/bug"
    And the page part ".card:has-text('Tasks') .card-label" holds "blog"
    And the page part ".page-head-sub" holds "4 items carry this tag"
    And the page part "a[href='/admin/projects/1']" holds "blog"
    And the page has no axe breaches in light or dark
    When I visit "/admin/tags/bug"
    Then the page parts ".card:has-text('Tasks') .li-title" read "A private bug"

  Scenario: A project tag's page caps a kind and pages the rest
    Given I am signed in to the admin
    And 101 tasks in "blog" carry its tag "bug"
    When I visit "/admin/projects/BLOG/tags/bug"
    Then the page has 10 of ".card:has-text('Tasks') .li-title"
    And the page part ".card:has-text('Tasks') a:has-text('All 101')" has "href" set to "/admin/projects/BLOG/tags/bug?kind=tasks"
    When I visit "/admin/projects/BLOG/tags/bug?kind=tasks"
    Then the page has 100 of ".card:has-text('Tasks') .li-title"
    And the page has "a[href='/admin/projects/BLOG/tags/bug?kind=tasks&page=2']"
    When I visit "/admin/projects/BLOG/tags/bug?kind=tasks&page=3"
    Then the server answers 404

  Scenario: A project tag's page says when nothing carries the tag, and answers 404 for what it does not hold
    Given I am signed in to the admin
    And the tags table holds the rows:
      | name    | color   | scope   | project_id |
      | private | mk-blue | private |            |
    When I visit "/admin/projects/BLOG/tags/bug"
    Then the page part "main" holds "Nothing carries this tag yet."
    And the project tag pages answer:
      | path                                     | status |
      | /admin/projects/NOPE/tags/bug            | 404    |
      | /admin/projects/BLOG/tags/lonely         | 404    |
      | /admin/projects/BLOG/tags/private        | 404    |
      | /admin/projects/BLOG/tags/bug?kind=projects | 404 |
