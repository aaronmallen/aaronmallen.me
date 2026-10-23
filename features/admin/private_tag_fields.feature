Feature: Admin private tag fields
  Every field that takes private tags draws its choices from one list of private tags in their colors, which leaves
  out public and mail-only tags, and keeps a plain comma field for a save without scripts.

  Scenario: The private tag list answers 401 when signed out
    When I fetch the tag choices at "/admin/tags/private/choices"
    Then the tag choices answer 401

  Rule: Signed in

    Background:
      Given I am signed in to the admin
      And the tagging tags:
        | name   | scope   | color    |
        | ruby   | public  |          |
        | chores | private | mk-green |
      And the tagging records:
        | id | kind        | title          | tags           |
        | 7  | task        | Water plants   | health         |
        | 8  | task        | Pay the rent   | chores, health |
        | 7  | mail_thread | Your bill      | billing        |
        | 7  | decision    | Pick a host    |                |
        | 7  | journal_entry | one          |                |

    Scenario: The private tag list gives the private tags in their colors and may not be kept
      When I fetch the tag choices at "/admin/tags/private/choices"
      Then the tag choices answer 200
      And the tag choices come as JSON no one may keep
      And the tag choices list "chores, health"
      And the tag choices give "chores" the color "green"
      And the tag choices give "health" a color

    Scenario: The new task form points its labelled tags field at the private tags
      When I visit "/admin/tasks/new"
      Then the tagging page holds "main input[name='task[tags]'] + [data-tag-field-src='/admin/tags/private/choices']"
      And the tagging field "main input[name='task[tags]']" has the label "Tags"

    Scenario: The task drawer's edit form points at the private tags
      When I visit "/admin/tasks/7/edit"
      Then the tagging page holds "input[name='task[tags]'] + [data-tag-field-src='/admin/tags/private/choices']"
      And the tagging page lacks "input[name='task[tags]'] + [data-tag-field-src]:not([data-tag-field-src='/admin/tags/private/choices'])"

    Scenario: The journal box, the write dialog and the edit template point at the private tags
      When I visit "/admin/journal"
      Then the tagging page holds 2 of "input[name='entry[tags]'] + [data-tag-field-src='/admin/tags/private/choices']"
      And a tagging page template holds "data-tag-field-src=\"/admin/tags/private/choices\""

    Scenario: The decision editors point at the private tags
      When I visit "/admin/decisions/new"
      Then the tagging page holds 1 of "input[name='decision[tags]'] + [data-tag-field-src='/admin/tags/private/choices']"
      When I visit "/admin/decisions/7/edit"
      Then the tagging page holds 1 of "input[name='decision[tags]'] + [data-tag-field-src='/admin/tags/private/choices']"

    Scenario: The task rule forms suggest the private tags
      Given the tagging task rule "aaronmallen/*" carries "chores"
      When I visit "/admin/settings/tagging"
      Then the tagging page holds 2 of "input[name='rule[tags]'] + [data-tag-field]"
      And the tag picker "input[name='rule[tags]'] + [data-tag-field]" offers "chores, health"

    Scenario: The task edit form keeps a comma field for a save without scripts
      When I visit "/admin/tasks/8/edit"
      Then the tagging field "input[name='task[tags]']" holds "chores, health"

    Scenario Outline: The <path> page with private tag fields passes axe
      When I visit "<path>"
      Then the page has no axe breaches in light or dark

      Examples:
        | path                    |
        | /admin/tasks/new        |
        | /admin/tasks/7/edit     |
        | /admin/decisions/new    |
        | /admin/decisions/7/edit |
        | /admin/settings/tagging |
