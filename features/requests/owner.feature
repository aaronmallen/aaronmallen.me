Feature: The owner
  The site names its owner, from the settings, in the title, the navigation, the wordmark and the feed.

  Scenario: The home page names the owner in the title, the navigation and the wordmark
    When I visit "/"
    Then the page title is "Writing and projects | Aaron Allen"
    And the page has "a[aria-label='A A, Aaron Allen, home']"
    When I request "/"
    Then the body includes "<span>A<span class=\"wordmark-rest\">aron</span></span>"
    And the body includes "<span>A<span class=\"wordmark-rest\">llen</span></span>"

  Scenario: The feed is signed with the owner's name
    Given the posts:
      | title |
      | Hello |
    When I request "/writing.atom"
    Then the body includes "<name>Aaron Allen</name>"
