Feature: Footer
  The footer carries the copyright, the owner's h-card, the built with links, the profile links the settings hold
  and a link to the privacy page.

  Scenario: The footer keeps the copyright beside the name, the glasses hidden before it, and the owner's link rel=me
    When I visit "/"
    Then "footer .h-card" starts with the text "© this year Aaron Allen"
    And the page has "footer .h-card .site-footer-mark > span.site-footer-glasses:first-child[aria-hidden='true']"
    And the page has "footer .h-card a.p-name[rel='me']:not([target])"
    And the page has no axe breaches in light or dark

  Scenario: The built with links open in a new tab with no handle back
    When I visit "/"
    Then the texts of "footer a.site-footer-text-link[target='_blank'][rel='noopener']" are:
      | Hanami |
      | Phlex  |

  Scenario: Each profile link is labelled, stays in this tab and hides its icon, and an unset network is left out
    When I visit "/"
    Then the texts of "footer.site-footer a.site-footer-link" are:
      | github   |
      | bluesky  |
      | mastodon |
    And the page has no "footer.site-footer a.site-footer-link[target]"
    And the page has no "footer.site-footer a.site-footer-link i:not([aria-hidden='true'])"

  @timeout:180_000
  Scenario: In production, with every network set, the footer links the LinkedIn profile rel=me with its icon
    Given the site runs in production
    When I request "/"
    Then the body includes "<a class=\"site-footer-link\" rel=\"me\" href=\"https://www.linkedin.com/in/aaronmallen/\"><i class=\"fa-brands fa-linkedin\" aria-hidden=\"true\">"

  Scenario: The heart is labelled as an image
    When I visit "/"
    Then the page has "footer i.fa-heart[role='img'][aria-label='love']:not([aria-hidden])"

  Scenario Outline: The footer on <path> links to the privacy page
    Given the posts:
      | title | tags |
      | Hello | ruby |
    When I visit "<path>"
    Then "footer.site-footer" has a link "privacy" to "/privacy"

    Examples:
      | path               |
      | /                  |
      | /about             |
      | /contact           |
      | /privacy           |
      | /projects          |
      | /writing           |
      | /writing/hello     |
      | /writing/tags/ruby |
