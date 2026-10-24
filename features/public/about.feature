Feature: About
  The about page introduces the owner, points at the work he does, lists his career and closes with the
  contact form and his profiles. It publishes no address to write to.

  Scenario: The about page heads with the kicker, heading and lede, and points at the projects page and Hanakai
    When I visit "/about"
    Then "header.hd .kicker" reads "About"
    And "header.hd h1" reads "Hi, I’m Aaron"
    And "header.hd .ld" reads "Software engineer in San Antonio, Texas. Ruby at work, and a lot of Rust in the open."
    And ".g > .prose p:has-text('Most of my own time goes into Rust')" has a link "projects page" to "/projects"
    And ".g > .prose p:has-text('In Ruby I focus on Hanami')" has a link "Hanakai team" to "https://hanakai.org"
    And the page has no axe breaches in light or dark

  Scenario: The about page names none of the work or hobbies left behind, and no address to write to
    When I request "/about"
    Then the body does not match "(?i)Root Insurance|Commands and Queries|activeinteractor|domainic|\bsai\b|farg|overlanding"
    And the body does not include "mailto:"

  Scenario: The about page leaves out the career card while there is no history
    When I visit "/about"
    Then the page has no ".card"

  Scenario: The career card lists the rows in position order, after the prose and before the call to action
    Given the career history:
      | role   | position |
      | Second | 2        |
      | First  | 1        |
    When I visit "/about"
    Then ".card > h2.kicker" reads "Career"
    And the texts of ".card .crs .cr h3" are:
      | First  |
      | Second |
    And the classes of ".g > .prose, .g > aside.stack.stick > *" are:
      | prose |
      | card  |
      | cta   |

  Scenario: A career row shows the years, the role, the organization and the blurb
    Given the career history:
      | org       | role              | blurb        | from | to   |
      | Rackspace | Software Engineer | Built things | 2018 | 2021 |
    When I visit "/about"
    Then ".crs .cr .yr" reads "2018–2021"
    And ".crs .cr h3" reads "Software Engineer"
    And ".crs .cr .at" reads "Rackspace"
    And ".crs .cr p" reads "Built things"

  Scenario: A current role names its open end
    Given the career history:
      | role    | from |
      | Current | 2021 |
    When I visit "/about"
    Then ".crs .cr .yr" reads "2021–Present"

  Scenario: A career row leaves the blurb out when it is blank
    Given the career history:
      | role    | blurb |
      | Blank   |       |
    When I visit "/about"
    Then the page has no ".crs .cr p"

  Scenario: The about page closes with the contact form and the profiles the settings hold
    When I visit "/about"
    Then the links in ".cta .links a" go to:
      | /contact                                |
      | https://github.com/aaronmallen          |
      | https://ruby.social/@aaronmallen        |
      | https://bsky.app/profile/aaronmallen.dev |
