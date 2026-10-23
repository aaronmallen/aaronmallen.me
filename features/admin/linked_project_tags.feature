Feature: Admin linked project tags
  A decision, journal entry, note, mail thread or post linked to a project takes that project's tags in place of
  private ones, offers them in its editor and menu, and drops them when the link goes. A post keeps its public tags
  beside them, and its project tags stay off the public site.

  Background:
    Given I am signed in to the admin
    And the tagging records:
      | kind    | title | key  |
      | project | blog  | BLOG |
      | project | pod   | POD  |

  Scenario: A decision with no project link keeps private tags
    Given the tagging records:
      | kind     | title     |
      | decision | Lone call |
    When I tag the decision "Lone call" with "home"
    Then the tagged decision "Lone call" holds "home in private"

  Scenario: A journal entry with no project link draws on the private tags
    Given the tagging tags:
      | name | scope   |
      | home | private |
    And the tagging records:
      | id | kind          | title     |
      | 9  | journal_entry | Quiet day |
    When I fetch the tag choices at "/admin/tags/private/choices?record=journal_entry&id=9"
    Then the tag choices list "home"

  Scenario: A note linked to a project takes a project tag and drops it when the link goes
    Given the tagging records:
      | kind | title      |
      | note | Feed notes |
    And the tagging note "Feed notes" links to the project "BLOG"
    When I tag the note "Feed notes" with "bug"
    Then the tagged note "Feed notes" holds "bug in BLOG"
    When the tagging note "Feed notes" no longer links to the project "BLOG"
    Then the tagged note "Feed notes" holds ""

  Scenario: A post with no project link shows no project tags field
    Given the tagging records:
      | id | kind | title     |
      | 9  | post | Lone post |
    When I visit "/admin/posts/9/edit"
    Then the tagging page holds "input[name='post[title]']"
    And the tagging page lacks "[name='post[project_tags]']"

  Scenario: The project tag page lists the decisions, notes, journal entries, mail and posts that carry it
    Given the tagging records:
      | kind          | title               | tags     |
      | decision      | Drop the feed       | BLOG:bug |
      | note          | Feed notes          | BLOG:bug |
      | journal_entry | Chased the feed bug | BLOG:bug |
      | mail_thread   | Feed broke          | BLOG:bug |
      | post          | Fixing the feed     | BLOG:bug |
    When I visit "/admin/projects/BLOG/tags/bug"
    Then the tagging page lists "Drop the feed, Feed notes, Chased the feed bug, Feed broke, Fixing the feed" in ".li-title"

  Scenario Outline: The <path> page that shows project tags passes axe
    Given the tagging records:
      | id | kind     | title         | tags     |
      | 7  | decision | Drop the feed | BLOG:bug |
      | 7  | post     | Fixing things | BLOG:bug |
    And the tagging post "Fixing things" links to the project "BLOG"
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path                          |
      | /admin/projects/BLOG/tags/bug |
      | /admin/posts/7/edit           |
      | /admin/decisions/7/edit       |
      | /writing/fixing-things        |

  Rule: A decision linked to a project

    Background:
      Given the tagging records:
        | id | kind     | title       | tags |
        | 7  | decision | Pick a host | old  |
      And the tagging decision "Pick a host" links to the project "BLOG"

    Scenario: Saving a name the project holds takes the project's tag and makes no private one
      Given the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
      When I save the decision editor for "Pick a host" with:
        | decision[tags] | bug |
        | decision[note] |     |
      Then the tagged decision "Pick a host" holds "bug in BLOG"
      And the database answers "0" for:
        """
        select count(*) from tags where scope = 'private' and name = 'bug'
        """

    Scenario: Saving a new name makes it in the project
      When I save the decision editor for "Pick a host" with:
        | decision[tags] | hosting |
        | decision[note] |         |
      Then the tagged decision "Pick a host" holds "hosting in BLOG"

    Scenario: Saving a new name makes it in each linked project
      Given the tagging decision "Pick a host" links to the project "POD"
      When I save the decision editor for "Pick a host" with:
        | decision[tags] | hosting |
        | decision[note] |         |
      Then the tagged decision "Pick a host" holds "hosting in BLOG, hosting in POD"

    Scenario: Saving a name only some linked projects hold uses only those projects
      Given the tagging decision "Pick a host" links to the project "POD"
      And the tagging tags:
        | name | scope       |
        | bug  | project POD |
      When I save the decision editor for "Pick a host" with:
        | decision[tags] | bug |
        | decision[note] |     |
      Then the tagged decision "Pick a host" holds "bug in POD"

    Scenario: The tag menu adds a project tag and takes it off
      When I tag the decision "Pick a host" with "bug"
      Then the tagged decision "Pick a host" holds "bug in BLOG, old in private"
      When I take the tag "bug" off the decision "Pick a host"
      Then the tagged decision "Pick a host" holds "old in private"

    Scenario: The tag menu takes off a project tag the editor saved
      When I save the decision editor for "Pick a host" with:
        | decision[tags] | bug |
        | decision[note] |     |
      And I take the tag "bug" off the decision "Pick a host"
      Then the tagged decision "Pick a host" holds ""

    Scenario: The editor offers the tags of every linked project and the menu the project's tags
      Given the tagging decision "Pick a host" links to the project "POD"
      And the tagging tags:
        | name  | scope        |
        | bug   | project BLOG |
        | infra | project POD  |
        | home  | private      |
      When I visit "/admin/decisions/7/edit"
      Then the tag picker "input[name='decision[tags]'] ~ .tag-pick" offers "bug, infra"
      When I visit "/admin/decisions/7/menu"
      Then the tag menu suggests "bug, infra"

    Scenario: The menu of a decision linked to one project offers that project's tags
      Given the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
        | home | private      |
      When I visit "/admin/decisions/7/menu"
      Then the tag menu suggests "bug"

    Scenario: The decision list links a project tag to the project's tag page
      When I save the decision editor for "Pick a host" with:
        | decision[tags] | bug |
        | decision[note] |     |
      And I visit "/admin/decisions"
      Then the tagging page holds "a[href='/admin/projects/BLOG/tags/bug']:text-is('#bug')"

    Scenario: Unlinking a project drops its tags and keeps the other project's
      Given the tagging decision "Pick a host" links to the project "POD"
      When I save the decision editor for "Pick a host" with:
        | decision[tags] | bug |
        | decision[note] |     |
      And the tagging decision "Pick a host" no longer links to the project "BLOG"
      Then the tagged decision "Pick a host" holds "bug in POD"
      And the database answers "1" for:
        """
        select count(*) from tags join projects on projects.id = tags.project_id where key = 'BLOG' and tags.name = 'bug'
        """

  Rule: A journal entry linked to a project

    Background:
      Given the tagging records:
        | id | kind          | title               |
        | 7  | journal_entry | Chased the feed bug |
      And the tagging journal_entry "Chased the feed bug" links to the project "BLOG"

    Scenario: The tag menu gives a journal entry a project tag, and unlinking drops it
      When I tag the journal_entry "Chased the feed bug" with "bug"
      Then the tagged journal_entry "Chased the feed bug" holds "bug in BLOG"
      When the tagging journal_entry "Chased the feed bug" no longer links to the project "BLOG"
      Then the tagged journal_entry "Chased the feed bug" holds ""

    Scenario: A journal entry's edit form draws on the project's tags
      Given the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
        | home | private      |
      When I visit "/admin/journal"
      Then the tagging page holds ".journal-entry[data-journal-tag-choices='/admin/tags/private/choices?record=journal_entry&id=7']"
      When I fetch the tag choices at "/admin/tags/private/choices?record=journal_entry&id=7"
      Then the tag choices list "bug"

  Rule: A mail thread linked to a project

    Background:
      Given the tagging records:
        | kind        | title      |
        | mail_thread | Feed broke |
      And the tagging mail_thread "Feed broke" links to the project "BLOG"

    Scenario: Tagging a linked mail thread takes a project tag
      When I tag the mail_thread "Feed broke" with "bug"
      Then the tagged mail_thread "Feed broke" holds "bug in BLOG"

    Scenario: A linked mail thread's menu offers the project's tags
      Given the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
        | home | private      |
      When I visit the mail_thread "Feed broke" at "/menu"
      Then the tag menu suggests "bug"

  Rule: A post linked to a project

    Background:
      Given the tagging records:
        | id | kind | title           | tags |
        | 7  | post | Fixing the feed | ruby |
      And the tagging post "Fixing the feed" links to the project "BLOG"

    Scenario: A post keeps its public tags beside the project's tags
      When I save the post editor for "Fixing the feed" with:
        | post[project_tags] | bug |
      Then the tagged post "Fixing the feed" holds "bug in BLOG, ruby in public"

    Scenario: A post keeps its project tags when only the public tags change
      When I save the post editor for "Fixing the feed" with:
        | post[project_tags] | bug |
      And I save the post editor for "Fixing the feed" with:
        | post[tags] | ruby, hanami |
      Then the tagged post "Fixing the feed" holds "bug in BLOG, hanami in public, ruby in public"

    Scenario: A linked post's editor offers a project tags field with the project's tags
      Given the tagging tags:
        | name | scope        |
        | bug  | project BLOG |
        | home | private      |
      When I visit "/admin/posts/7/edit"
      Then the tag picker "input[name='post[project_tags]'] ~ .tag-pick" offers "bug"

    Scenario: The public post and tag page leave the project's tags off
      When I save the post editor for "Fixing the feed" with:
        | post[project_tags] | bug |
      And I visit "/writing/fixing-the-feed"
      Then I see the heading "Fixing the feed"
      And the tagging page source lacks "bug"
      And visiting "/writing/tags/bug" answers 404
