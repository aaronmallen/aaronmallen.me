Feature: Admin menu tag suggestions
  A record's menu suggests the tags its kind takes: mail menus every private tag, mail-only ones too, other private
  kinds the private tags no mail-only tag, and posts the public tags.

  Background:
    Given I am signed in to the admin
    And the tagging tags:
      | name | scope   | color   |
      | home | private | mk-blue |
      | ruby | public  |         |
    And the tagging records:
      | id | kind          | title          | tags     |
      | 7  | mail_thread   | Feed broke     | receipts |
      | 7  | task          | Fix the feed   |          |
      | 7  | journal_entry | Wrote the feed |          |
      | 7  | decision      | Pick a host    |          |
      | 7  | post          | Fixing things  |          |

  Scenario: A mail menu suggests every private tag, mail-only ones too, with their colors
    When I visit the mail_thread "Feed broke" at "/menu"
    Then the tag menu suggests "home, receipts"
    And the tag menu gives "home" the color "blue"
    And the tag menu gives "receipts" a color

  Scenario Outline: The <menu> leaves mail-only tags out
    When I visit "<path>"
    Then the tag menu suggests "home"

    Examples:
      | menu           | path                           |
      | task menu      | /admin/tasks/7/menu            |
      | task bulk menu | /admin/tasks/bulk/menu?ids[]=7 |
      | journal menu   | /admin/journal/7/menu          |
      | decision menu  | /admin/decisions/7/menu        |

  Scenario: A post menu suggests the public tags
    When I visit the post "Fixing things" at "/menu"
    Then the tag menu suggests "ruby"

  Scenario Outline: The <path> page these menus open from passes axe
    When I visit "<path>"
    Then the page has no axe breaches in light or dark

    Examples:
      | path         |
      | /admin/mail  |
      | /admin/tasks |
      | /admin/posts |
