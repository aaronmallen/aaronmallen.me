Feature: Admin post, social, project and person row menus
  Post, social, project and person rows carry a right-click menu. The server draws each menu for its record,
  holds only the actions that record can take, and posts each action by fetch back to the page it opened on.

  Background:
    Given I am signed in to the admin

  Scenario Outline: A row menu answers 404 for a <kind> row that is gone
    Then visiting "/admin/<kind>/0/menu" answers 404

    Examples:
      | kind     |
      | posts    |
      | social   |
      | projects |
      | people   |

  Scenario: A published post's menu holds what a published post takes and posts back by fetch
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-blue', 'public'), ('elixir', 'mk-blue', 'public'),
        ('home', 'mk-blue', 'private');
      INSERT INTO posts (title, slug, status, published_at, body, body_html, webmentions_enabled, read_time, word_count)
      VALUES ('Hello', 'hello', 'published', now() - interval '1 day', 'Hi.', '<p>Hi.</p>', false, 1, 1);
      INSERT INTO post_tags (post_id, tag_id) SELECT 1, id FROM tags WHERE name = 'ruby';
      """
    When I visit "/admin/posts/1/menu?return_to=/admin/x?y=1"
    Then the menu head reads "Hello"
    And the menu items include "Edit, Analytics, View on site, Tags, Copy link"
    And the menu items leave out "Keep writing, Delete draft"
    And the menu copies "Copy link" ending with "/writing/hello"
    And the admin markup holds "a.ctx-item[target=_blank][href$='/writing/hello']"
    And the admin markup holds "[role=menuitemcheckbox][aria-checked=true]:has-text('#ruby')"
    And the admin markup holds "[role=menuitemcheckbox][aria-checked=false]:has-text('#elixir')"
    And the admin markup lacks "[role=menuitemcheckbox]:has-text('#home')"
    And a menu form "form[action='/admin/posts/bulk']" holds the fields:
      | act   | untag |
      | ids[] | 1     |
      | tag   | ruby  |
    And a menu form "form[action='/admin/posts/bulk']" holds the fields:
      | act   | tag    |
      | ids[] | 1      |
      | tag   | elixir |
    And the admin markup lacks "[data-context-menu] form:not([data-morph])"
    And every menu form returns to "/admin/x?y=1"

  Scenario: A draft post's menu offers keep writing and a delete that asks first and keeps the list's place
    Given the database runs:
      """
      INSERT INTO posts (title, slug, body, body_html, webmentions_enabled, read_time, word_count)
      VALUES ('Draft', 'draft', 'Hi.', '<p>Hi.</p>', false, 1, 1);
      """
    When I visit "/admin/posts/1/menu?status=draft&page=2&return_to=/admin/x?y=1"
    Then the menu items include "Keep writing, Tags, Delete draft"
    And the menu items leave out "Edit, Analytics, View on site, Copy link"
    And the admin markup holds "button[data-confirm-inline='Click again to delete']:has-text('Delete draft')"
    And the menu form "form:has(button[data-confirm-inline])" holds only the fields:
      | act    | delete |
      | ids[]  | 1      |
      | status | draft  |
      | page   | 2      |

  Scenario: A queued social post's menu holds what an unsent post takes, copies its text and asks before it removes
    Given the menu screens hold "a queued social post"
    When I visit "/admin/social/1/menu?filter=queued&return_to=/admin/x?y=1"
    Then the menu items read "Edit, Linked records, Copy text, Remove from queue"
    And the admin markup holds "a.ctx-item[href='/admin/social?filter=queued&edit=1#social-links']"
    And the menu copies "Copy text" as "Out soon."
    And the admin markup holds "form:has(button[data-confirm-inline]) button:has-text('Remove from queue')"
    And the menu form "form:has(button[data-confirm-inline])" holds only the fields:
      | filter | queued |

  Scenario: A draft social post's menu deletes the draft
    Given the database runs:
      """
      INSERT INTO social_posts (targets) VALUES ('{mastodon,bluesky}');
      INSERT INTO social_post_parts (social_post_id, position, body) VALUES (1, 1, 'Not yet.');
      """
    When I visit "/admin/social/1/menu?return_to=/admin/x?y=1"
    Then the menu items include "Delete draft"

  Scenario: A posted social post's menu offers only the copy
    Given the database runs:
      """
      INSERT INTO social_posts (targets, status, posted_at) VALUES ('{mastodon,bluesky}', 'posted', now() - interval '1 day');
      INSERT INTO social_post_parts (social_post_id, position, body) VALUES (1, 1, 'Sent.');
      """
    When I visit "/admin/social/1/menu?return_to=/admin/x?y=1"
    Then the menu items read "Copy text"

  Scenario: A live project's menu opens and copies the repo, tags and untags and posts back by fetch
    Given the database runs:
      """
      INSERT INTO tags (name, color, scope) VALUES ('ruby', 'mk-blue', 'public'), ('home', 'mk-blue', 'private');
      INSERT INTO projects (name, visibility, key, repo, url)
      VALUES ('Hanami', 'public', 'HAN', 'hanami/hanami', 'https://hanamirb.org');
      INSERT INTO project_tags (project_id, tag_id) SELECT 1, id FROM tags WHERE name = 'ruby';
      """
    When I visit "/admin/projects/1/menu?return_to=/admin/x?y=1"
    Then the menu items read "Open board, Edit, Open repo, Open site, Tags, #ruby, Copy repo, Archive"
    And the admin markup holds "a.ctx-item[target=_blank][href='https://github.com/hanami/hanami']"
    And the admin markup holds "a.ctx-item[target=_blank][href='https://hanamirb.org']"
    And the menu copies "Copy repo" as "hanami/hanami"
    And the admin markup lacks "[role=menuitemcheckbox]:has-text('#home')"
    And the admin markup holds "form[action='/admin/projects/1/tags/delete'] input[name='tag'][value='ruby']"
    And the admin markup holds "form[action='/admin/projects/1/tags'] input[name=tag][pattern]"
    And the admin markup lacks "[data-context-menu] form:not([data-morph])"
    And every menu form returns to "/admin/x?y=1"

  Scenario: An archived project with no repo offers restore and nothing that needs the repo
    Given the database runs:
      """
      INSERT INTO projects (name, visibility, key, archived_on) VALUES ('Old', 'public', 'OLD', current_date);
      """
    When I visit "/admin/projects/1/menu?return_to=/admin/x?y=1"
    Then the menu items include "Edit, Tags, Restore"
    And the menu items leave out "Archive, Open repo, Open site, Copy repo"

  Scenario: A person's menu holds open, edit, copy mention and a delete that asks first
    Given the menu screens hold "a person"
    When I visit "/admin/contacts/1/menu?return_to=/admin/x?y=1"
    Then the menu items read "Open, Edit, Copy mention, Delete"
    And the menu copies "Copy mention" as "@{matz}"
    And the admin markup holds "button[data-confirm-inline='Click again to delete']:has-text('Delete')"
    And the admin markup lacks "[data-context-menu] form:not([data-morph])"
    And every menu form returns to "/admin/x?y=1"

  Scenario: Post rows carry the menu
    Given the menu screens hold "two drafts"
    When I visit "/admin/posts"
    Then the admin markup holds ".li[data-menu='/admin/posts/1/menu?status=all']"

  Scenario: Social queue rows carry the menu
    Given the menu screens hold "a queued social post"
    When I visit "/admin/social"
    Then the admin markup holds ".sq-item[data-menu='/admin/social/1/menu?filter=queued']"

  Scenario: Project cards carry the menu
    Given the menu screens hold "a project"
    When I visit "/admin/projects"
    Then the admin markup holds ".project-card[data-menu='/admin/projects/1/menu']"

  Scenario: People rows carry the menu
    Given the menu screens hold "a person"
    When I visit "/admin/contacts"
    Then the admin markup holds ".contact-row[data-menu='/admin/contacts/1/menu']"

  Scenario: Tagging a post from its menu lands back on the page it opened on
    Given the menu screens hold "two drafts"
    When I post the form to the admin "/admin/posts/bulk" with:
      | act       | untag        |
      | ids[]     | 1            |
      | tag       | ruby         |
      | return_to | /admin/x?y=1 |
    Then the admin post sends me to "/admin/x?y=1"

  Scenario: Archiving and restoring a project from its menu lands back on the page it opened on
    Given the menu screens hold "a project"
    When I post the form to the admin "/admin/projects/1/archive" with:
      | return_to | /admin/x?y=1 |
    Then the admin post sends me to "/admin/x?y=1"
    When I post the form to the admin "/admin/projects/1/restore" with:
      | return_to | /admin/x?y=1 |
    Then the admin post sends me to "/admin/x?y=1"

  Scenario: Removing a person from the menu lands back on the page it opened on
    Given the menu screens hold "a person"
    When I post the form to the admin "/admin/contacts/1/delete" with:
      | return_to | /admin/x?y=1 |
    Then the admin post sends me to "/admin/x?y=1"

  Scenario: A menu action ignores a return path outside the admin
    Given the menu screens hold "a person"
    When I post the form to the admin "/admin/contacts/1/delete" with:
      | return_to | https://example.com/ |
    Then the admin post sends me to "/admin/contacts"

  Scenario Outline: The screens with row menus pass axe at <path>
    Given the menu screens hold "<seed>"
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | seed                 | path            |
      | two drafts           | /admin/posts    |
      | a queued social post | /admin/social   |
      | a project            | /admin/projects |
      | a person             | /admin/contacts |
