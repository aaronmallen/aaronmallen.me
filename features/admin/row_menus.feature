Feature: Admin row menus in the browser
  A right-click on a row opens its menu. Picking an item acts in place: the page stays, the row changes and a toast
  says what happened. A delete asks for a second click first.

  Background:
    Given I am signed in to the admin

  Scenario: A post's tag menu lists only public tags
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-blue', 'public'), ('home', 'mk-blue', 'private');
      """
    And the menu screens hold "two drafts"
    When I visit "/admin/posts"
    And I open the row menu on ".li[data-menu] .pill"
    And I point at "Tags" in the row menu
    Then the row menu holds "[role=menuitemcheckbox]:has-text('#ruby')"
    And the row menu does not mention "#home"

  Scenario: Ticking a tag in a post's menu tags it in place
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-blue', 'public');
      """
    And the menu screens hold "two drafts"
    When I visit "/admin/posts"
    And I open the row menu on ".li[data-menu] .pill"
    And I point at "Tags" in the row menu
    And I pick "#ruby" in the row menu
    Then a row toast says "Tagged 1 post ruby"
    And ".li .tag:has-text('ruby')" shows
    And the row page stayed

  Scenario: A post's menu asks for a second click before it deletes, then deletes the draft in place
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, webmentions_enabled, read_time, word_count)
      VALUES ('Hello', 'hello', 'Hi.', '<p>Hi.</p>', false, 1, 1);
      """
    When I visit "/admin/posts"
    And I open the row menu on ".li[data-menu] .pill"
    And I pick "Delete draft" in the row menu
    Then the row menu offers "Click again to delete"
    When I pick "Click again to delete" in the row menu
    Then a row toast says "Deleted 1 draft"
    And the admin markup lacks ".li[data-menu]"
    And the row page stayed

  Scenario: Unticking a tag in a project's menu untags it in place
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-blue', 'public');
      INSERT INTO projects (name, visibility, key) VALUES ('Hanami', 'public', 'HAN');
      INSERT INTO project_tags (project_id, tag_id) VALUES (1, 1);
      """
    When I visit "/admin/projects"
    And I open the row menu on ".project-card"
    And I point at "Tags" in the row menu
    And I pick "#ruby" in the row menu
    Then a row toast says "Took ruby off"
    And the database soon answers "0" for:
      """
      SELECT count(*) FROM project_tags
      """
    And the row page stayed

  Scenario: A project's menu archives it in place
    Given the menu screens hold "a project"
    When I visit "/admin/projects"
    And I open the row menu on ".project-card"
    And I pick "Archive" in the row menu
    Then a row toast says "Archived · removed from /projects"

  Scenario: A queued social post's menu removes it in place on the second click
    Given the menu screens hold "a queued social post"
    When I visit "/admin/social"
    And I open the row menu on ".sq-item"
    And I pick "Remove from queue" in the row menu
    And I pick "Click again to remove" in the row menu
    Then a row toast says "Removed from queue"
    And the admin markup lacks ".sq-item"
    And the row page stayed

  Scenario: A person's menu copies the mention and shows a toast
    Given the menu screens hold "a person"
    When I visit "/admin/contacts"
    And I watch the row menu clipboard
    And I open the row menu on ".contact-row"
    And I pick "Copy mention" in the row menu
    Then a row toast says "Mention copied"
    And the row menu clipboard holds "@{matz}"

  Scenario: A person's menu deletes the contact on the second click
    Given the menu screens hold "a person"
    When I visit "/admin/contacts"
    And I open the row menu on ".contact-row"
    And I pick "Delete" in the row menu
    And I pick "Click again to delete" in the row menu
    Then a row toast says "Contact deleted"
    And the admin markup lacks ".contact-row"

  Scenario: A menu opens on a row that is itself a link
    Given the database runs:
      """
      INSERT INTO commits (sha, repo, branch, message, commit_date, commit_time)
      VALUES (repeat('ab', 20), 'aaronmallen/blog', 'main', 'add the view',
              (now() AT TIME ZONE 'America/Chicago')::date, '09:00');
      """
    When I visit "/admin/activity"
    And I open the row menu on "a.activity-event:has-text('add the view')"
    Then the row menu holds ".ctx-item:has-text('Copy SHA')"

  Scenario: A task comment's menu opens its edit form in place from Edit
    Given the menu screens hold "a task comment"
    When I visit "/admin/tasks/1"
    And I open the row menu on "#task-comment-1 .comment-head"
    And I pick "Edit" in the row menu
    Then "#task-comment-1 details.comment-edit[open]" shows
    And the row page stayed

  Scenario: A task rule's menu opens its editor from Edit
    Given the menu screens hold "a task rule"
    When I visit "/admin/settings/tagging"
    And I open the row menu on ".rule-row .rule-provider"
    And I pick "Edit" in the row menu
    Then the admin markup holds "#rule-1-edit:checked"

  Scenario: A token's menu revokes it in place on the second click
    Given the menu screens hold "a token"
    When I visit "/admin/settings/services"
    And I open the row menu on ".li .li-title:has-text('Terminal')"
    And I pick "Revoke" in the row menu
    And I pick "Click again to revoke" in the row menu
    Then a row toast says "Token revoked"
    And the admin markup lacks ".li-title:has-text('Terminal')"
    And the row page stayed
