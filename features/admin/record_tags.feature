Feature: Admin record tags
  The tag menu on a journal entry, a decision or a project adds a tag or takes one off, then goes back with a toast.
  Journal entries and decisions take private tags; projects take public ones.

  Background:
    Given I am signed in to the admin
    And the tagging records:
      | kind          | title          | tags |
      | journal_entry | Wrote the feed | ruby |
      | decision      | Pick a host    | ruby |
      | project       | blog           | ruby |

  Scenario Outline: Tagging a <kind> adds the tag in its scope, keeps the others and goes back with a toast
    When I tag the <kind> "<record>" with " Hanami "
    Then the tagged <kind> "<record>" holds "hanami in <scope>, ruby in <scope>"
    And the database answers "<scope>" for:
      """
      select string_agg(scope::text, ', ') from tags where name = 'hanami'
      """
    And the tagging form sends me to "<list>"
    And the tagging form toasts "Tagged hanami"

    Examples:
      | kind          | record         | scope   | list            |
      | journal_entry | Wrote the feed | private | /admin/journal  |
      | decision      | Pick a host    | private | /admin/decisions |
      | project       | blog           | public  | /admin/projects |

  Scenario Outline: A <kind> takes a tag whose name the other scope holds
    Given the tagging tags:
      | name   | scope   |
      | elixir | <other> |
    When I tag the <kind> "<record>" with "elixir"
    Then the tagged <kind> "<record>" holds "elixir in <scope>, ruby in <scope>"
    And the database answers "private, public" for:
      """
      select string_agg(scope::text, ', ' order by scope::text) from tags where name = 'elixir'
      """

    Examples:
      | kind          | record         | scope   | other   |
      | journal_entry | Wrote the feed | private | public  |
      | decision      | Pick a host    | private | public  |
      | project       | blog           | public  | private |

  Scenario Outline: Taking the tag off a <kind> says so
    When I take the tag "ruby" off the <kind> "<record>"
    Then the tagged <kind> "<record>" holds ""
    And the tagging form toasts "Took ruby off"

    Examples:
      | kind          | record         |
      | journal_entry | Wrote the feed |
      | decision      | Pick a host    |
      | project       | blog           |

  Scenario Outline: Tagging a <kind> goes back where the menu asked, but never off the admin
    When I tag the <kind> "<record>" with "hanami", asking to return to "/admin/tags/hanami"
    Then the tagging form sends me to "/admin/tags/hanami"
    When I tag the <kind> "<record>" with "hanami", asking to return to "https://example.com/"
    Then the tagging form sends me to "<list>"

    Examples:
      | kind          | record         | list             |
      | journal_entry | Wrote the feed | /admin/journal   |
      | decision      | Pick a host    | /admin/decisions |
      | project       | blog           | /admin/projects  |

  Scenario Outline: Tagging a <kind> with a blank or a bad tag changes nothing and says why
    When I tag the <kind> "<record>" with " "
    Then the tagging form toasts "Type a tag first"
    And the tagged <kind> "<record>" holds "ruby in <scope>"
    When I tag the <kind> "<record>" with "not a tag!"
    Then the tagging form toasts "Nothing changed · a tag takes lowercase letters, numbers and dashes"
    And the tagged <kind> "<record>" holds "ruby in <scope>"

    Examples:
      | kind          | record         | scope   |
      | journal_entry | Wrote the feed | private |
      | decision      | Pick a host    | private |
      | project       | blog           | public  |

  Scenario Outline: Tagging a <kind> that is gone answers 404
    When I tag the <kind> "that is gone" with "ruby"
    Then the tagging form answers 404

    Examples:
      | kind          |
      | journal_entry |
      | decision      |
      | project       |

  Scenario Outline: The <list> page a tag goes back to passes axe
    When I visit "<list>"
    Then the page has no axe breaches in light or dark

    Examples:
      | list             |
      | /admin/journal   |
      | /admin/decisions |
      | /admin/projects  |
