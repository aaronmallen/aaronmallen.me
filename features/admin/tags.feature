Feature: Admin tag manager
  The tagging tab lists the public and the private tags, says what carries each one, and keeps the editor for
  each tag in the side panel.

  Scenario: The tag manager shows no tag to a visitor who has not signed in
    Given the tag manager holds the public tags "ruby"
    When I visit "/admin/settings/tagging"
    Then I am sent to sign in
    And the tag manager's page source lacks "ruby"

  Rule: The owner has signed in

    Background:
      Given I am signed in to the admin

    Scenario: The palette opens the tagging tab
      When I visit "/admin"
      Then the tag manager shows "[data-palette-href='/admin/settings/tagging']"

    Scenario: The old tags address sends to the tagging tab with its scope, search and page
      Then the tag manager sends "/admin/tags?scope=private&q=ho&page=2" to "/admin/settings/tagging?scope=private&q=ho&page=2#tags"
      And the tag manager sends "/admin/tags" to "/admin/settings/tagging?scope=public#tags"

    Scenario: The tag manager says so when there is no tag yet
      When I visit "/admin/settings/tagging"
      Then the tag manager shows ".empty"

    Scenario: The private tab says it has no tags yet
      Given these records carry tags for the tag manager:
        | kind | title   | tags |
        | post | On ruby | ruby |
      When I visit "/admin/settings/tagging?scope=private"
      Then the tag manager shows ".card-blurb" reading exactly "0 tags · only you see these, on tasks and the journal"
      And the tag manager shows ".empty" reading exactly "No tags yet. Name one above."

    Scenario: The list shows each tag in name order, in its colour, with its count, link and edit button
      Given the tag manager holds these tags:
        | name | color    |
        | ruby | mk-green |
      And these records carry tags for the tag manager:
        | kind | title   | tags         |
        | post | On ruby | ruby, hanami |
      When I visit "/admin/settings/tagging"
      Then the tag manager lists ".tag-name" as "#hanami, #ruby"
      And the tag manager shows ".card-blurb" reading "2 tags"
      And the tag manager shows ".tag-name .tag.green" reading "#ruby"
      And the tag manager shows ".tag-row a[href='/admin/tags/ruby']" reading "#ruby"
      And the tag manager shows ".tag-row:has-text('#ruby') a.bt.tag-pen[href='#tag-{public:ruby}-editor'][title='Edit'][aria-label='Edit']" reading exactly ""
      And the tag manager shows "aside.settings-side #tag-{public:ruby}-editor.tag-editor"
      And the tag manager shows no ".tag-row form"
      And the tag manager shows no ".tag-editor-open"
      And the tag manager lists ".tag-uses" as "1 post, 1 post"

    Scenario: A public tag counts each public kind it is on
      Given these records carry tags for the tag manager:
        | kind    | title    | tags |
        | post    | On ruby  | ruby |
        | project | ruby-gem | ruby |
        | task    | Bump it  | ruby |
      When I visit "/admin/settings/tagging"
      Then the tag manager shows ".tag-row:has-text('#ruby') .tag-uses" reading exactly "1 post · 1 project"

    Scenario: A private tag counts each private kind it is on
      Given these records carry tags for the tag manager:
        | kind          | title       | tags |
        | task          | Bump it     | ruby |
        | journal entry | Wrote ruby  | ruby |
        | decision      | Pick a ruby | ruby |
      When I visit "/admin/settings/tagging?scope=private"
      Then the tag manager shows ".tag-uses" reading exactly "1 journal entry · 1 task · 1 decision"

    Scenario: A private tag counts the messages it is on
      Given these records carry tags for the tag manager:
        | kind    | title | tags |
        | message | Hi    | ruby |
        | message | Hello | ruby |
      When I visit "/admin/settings/tagging?scope=private"
      Then the tag manager shows ".tag-uses" reading exactly "2 messages"

    Scenario: A private tag counts the task rules that hold it
      Given these records carry tags for the tag manager:
        | kind | title   | tags |
        | task | Bump it | ruby |
      And the tag manager has a task rule "rails/*" tagged "ruby"
      And the tag manager has a task rule "hanami/*" tagged "ruby"
      When I visit "/admin/settings/tagging?scope=private"
      Then the tag manager shows ".tag-uses" reading exactly "1 task · 2 rules"

    Scenario: A tag nothing carries reads as unused
      Given the tag manager holds the public tags "elixir"
      When I visit "/admin/settings/tagging"
      Then the tag manager shows ".tag-uses" reading "unused"

    Scenario: The filter narrows the list and says when it matches nothing
      Given these records carry tags for the tag manager:
        | kind | title   | tags         |
        | post | On ruby | ruby, hanami |
      When I visit "/admin/settings/tagging?q=ru"
      Then the tag manager lists ".tag-name" as "#ruby"
      When I visit "/admin/settings/tagging?q=elixir"
      Then the tag manager shows ".empty" reading "elixir"

    Scenario: The scope switch opens on the public tags and falls back to them
      Given these records carry tags for the tag manager:
        | kind | title   | tags   |
        | post | On ruby | ruby   |
        | task | Sweep   | chores |
      When I visit "/admin/settings/tagging"
      Then the tag manager lists ".tag-name" as "#ruby"
      And the tag manager shows "a[href='/admin/settings/tagging?scope=public#tags']" reading "Public"
      And the tag manager shows "a[href='/admin/settings/tagging?scope=private#tags']" reading "Private"
      And the tag manager shows "form[method='get'][action='/admin/settings/tagging'][role='search'][data-autosubmit]"
      When I visit "/admin/settings/tagging?scope=secret"
      Then the tag manager lists ".tag-name" as "#ruby"

    Scenario: The private tab lists only private tags and marks its tab
      Given these records carry tags for the tag manager:
        | kind | title   | tags   |
        | post | On ruby | ruby   |
        | task | Sweep   | chores |
      When I visit "/admin/settings/tagging?scope=private"
      Then the tag manager lists ".tag-name" as "#chores"
      And the tag manager shows "a.seg-option.current[aria-current='page']" reading "Private"
      And the tag manager shows "form[role='search'] input[name='scope'][value='private']"
      And the tag manager shows ".card-blurb" reading "1 tag"

    Scenario: The scope switch keeps the search and searches inside the scope
      Given these records carry tags for the tag manager:
        | kind | title   | tags   |
        | post | On ruby | ruby   |
        | task | Sweep   | chores |
      When I visit "/admin/settings/tagging?q=ch"
      Then the tag manager shows "a[href='/admin/settings/tagging?scope=private&q=ch#tags']" reading "Private"
      When I visit "/admin/settings/tagging?scope=private&q=r"
      Then the tag manager lists ".tag-name" as "#chores"

    Scenario: A name a post and a task carry is one tag on each tab
      Given these records carry tags for the tag manager:
        | kind | title   | tags    |
        | post | On it   | hanakai |
        | task | Sweep   | hanakai |
      When I visit "/admin/settings/tagging?scope=public"
      Then the tag manager shows ".tag-row:has-text('#hanakai') .tag-uses" reading exactly "1 post"
      When I visit "/admin/settings/tagging?scope=private"
      Then the tag manager shows ".tag-row:has-text('#hanakai') .tag-uses" reading exactly "1 task"

    Scenario Outline: The tag pages pass axe in light and dark
      Given these records carry tags for the tag manager:
        | kind          | title       | tags      |
        | post          | On ruby     | ruby      |
        | task          | Sweep       | ruby      |
        | journal entry | Wrote ruby  | ruby      |
        | decision      | Pick a ruby | ruby      |
      And the tag manager has the project "blog" keyed "BLOG"
      And the tag manager holds these tags:
        | name | project | description     |
        | bug  | blog    | something broke |
      When I visit "<path>"
      Then the page has no axe breaches in light or dark

      Examples:
        | path                                    |
        | /admin/settings/tagging                 |
        | /admin/settings/tagging?scope=private   |
        | /admin/tags/ruby                        |
        | /admin/tags/ruby?kind=tasks             |
        | /admin/projects/BLOG/tags/bug           |
        | /admin/projects/1                       |
