Feature: Admin bulk context menu
  A right-click on a picked row opens the bulk menu for every picked row. It names how many are picked and acts on
  them all at once. A row that is not picked, or the only one picked, opens its own menu.

  Background:
    Given I am signed in to the admin

  Rule: On tasks

    Background:
      Given the database runs:
        """
        INSERT INTO tasks (title, list, position)
        VALUES ('first', 'next', 1), ('second', 'next', 2), ('third', 'next', 3), ('fourth', 'next', 4);
        """
      When I visit "/admin/tasks?filter=next"
      And I click the button "Select"
      And I tick the ".task" rows holding "first, second, third"

    Scenario: A picked task row opens the bulk menu that names how many are picked
      When I open the row menu on ".task:has-text('second') .record-key"
      Then the menu head reads "3 tasks picked"

    Scenario: The bulk menu completes every picked task
      When I open the row menu on ".task:has-text('second') .record-key"
      And I pick "Complete" in the row menu
      Then a row toast says "Finished 3 tasks"
      And the database soon answers "fourth" for:
        """
        SELECT string_agg(title, ', ') FROM tasks WHERE status = 'open'
        """

    Scenario: The bulk menu moves every picked task
      When I open the row menu on ".task:has-text('first') .record-key"
      And I point at "Move to" in the row menu
      And I pick "Someday" in the row menu
      Then a row toast says "Moved 3 tasks"

    Scenario: The bulk menu tags every picked task
      Given the database runs:
        """
        INSERT INTO tags (name, color, scope) VALUES ('home', 'mk-blue', 'private');
        """
      When I open the row menu on ".task:has-text('third') .record-key"
      And I point at "Add tag" in the row menu
      And I pick "#home" in the row menu
      Then a row toast says "Tagged 3 tasks"

    Scenario: The bulk menu asks for a second click, then deletes every picked task
      When I open the row menu on ".task:has-text('first') .record-key"
      And I pick "Delete" in the row menu
      Then the row menu offers "Click again to delete"
      And the database answers "4" for:
        """
        SELECT count(*) FROM tasks WHERE status = 'open'
        """
      When I pick "Click again to delete" in the row menu
      Then a row toast says "Deleted 3 tasks"
      And the database soon answers "fourth" for:
        """
        SELECT string_agg(title, ', ') FROM tasks WHERE status = 'open'
        """

    Scenario: The bulk menu clears the selection
      When I open the row menu on ".task:has-text('first') .record-key"
      And I pick "Clear selection" in the row menu
      Then the row menu is shut
      And no row box is ticked

    Scenario: A task row that is not picked opens its own menu
      When I open the row menu on ".task:has-text('fourth') .record-key"
      Then the menu head reads "4 · fourth"

    Scenario: The only picked task row opens its own menu
      When I untick the ".task" rows holding "first, second"
      And I open the row menu on ".task:has-text('third') .record-key"
      Then the menu head reads "3 · third"

  Rule: On posts

    Background:
      Given the database runs:
        """
        INSERT INTO tags (name, color, scope) VALUES ('go', 'mk-blue', 'public'), ('ruby', 'mk-blue', 'public');
        INSERT INTO posts (title, slug, body, body_html, webmentions_enabled, read_time, word_count)
        VALUES ('one draft', 'one', 'Hi.', '<p>Hi.</p>', false, 1, 1), ('two draft', 'two', 'Hi.', '<p>Hi.</p>', false, 1, 1),
          ('three draft', 'three', 'Hi.', '<p>Hi.</p>', false, 1, 1);
        INSERT INTO post_tags (post_id, tag_id) SELECT id, 2 FROM posts;
        """
      When I visit "/admin/posts"
      And I tick the ".li" rows holding "one draft, two draft, three draft"
      And I open the row menu on ".li:has-text('two draft') .li-sub"

    Scenario: The posts bulk menu names how many posts are picked
      Then the menu head reads "3 posts picked"

    Scenario: The posts bulk menu tags every picked post
      When I point at "Add tag" in the row menu
      And I pick "#go" in the row menu
      Then a row toast says "Tagged 3 posts"

    Scenario: The posts bulk menu untags every picked post
      When I point at "Remove tag" in the row menu
      And I pick "#ruby" under "Remove tag" in the row menu
      Then a row toast says "Took ruby off 3 posts"

    Scenario: The posts bulk menu deletes every picked post on a second click
      When I pick "Delete" in the row menu
      Then the database answers "3" for:
        """
        SELECT count(*) FROM posts
        """
      When I pick "Click again to delete" in the row menu
      Then a row toast says "Deleted 3 drafts"
      And the database soon answers "0" for:
        """
        SELECT count(*) FROM posts
        """

  Rule: On webmentions

    Background:
      Given the database runs:
        """
        INSERT INTO posts (title, slug, status, published_at, body, body_html, webmentions_enabled, read_time, word_count)
        VALUES ('Target', 'target', 'published', now() - interval '1 day', 'A post.', '<p>A post.</p>', true, 1, 2);
        INSERT INTO webmentions (post_id, source_url, author_name, author_url, type, excerpt)
        SELECT 1, 'https://' || lower(name) || '.example/note', name, 'https://' || lower(name) || '.example/', 'mention',
                'A note from ' || name || '.'
        FROM unnest(ARRAY['Ada', 'Grace', 'Alan']) AS name;
        """
      When I visit "/admin/webmentions"
      And I tick the ".wm-card" rows holding "Ada, Grace, Alan"
      And I right-click the row part ".wm-card:has-text('Grace') .wm-who"

    Scenario: The webmentions bulk menu names how many webmentions are picked
      Then the menu head reads "3 webmentions picked"

    Scenario: The webmentions bulk menu approves every picked webmention
      When I pick "Approve" in the row menu
      Then a row toast says "Approved 3 webmentions"
      And the database soon answers "3" for:
        """
        SELECT count(*) FROM webmentions WHERE status = 'approved'
        """
