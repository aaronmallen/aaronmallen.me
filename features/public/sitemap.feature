Feature: Sitemap
  The sitemap lists the public pages, published posts, the tags they and live public projects carry, and each
  public project's published board, each dated by its last change.

  Scenario: The sitemap is valid XML and answers a crawler that takes anything
    Given the posts:
      | title | tags |
      | Hello | ruby |
    And my requests send the header "Accept" as "*/*"
    When I request "/sitemap.xml"
    Then the "Content-Type" header starts with "application/xml"
    And the XML answer passes the schema "sitemap.xsd"

  Scenario: The sitemap lists the public pages, published posts and their tags
    Given the posts:
      | title | tags         |
      | Hello | ruby, hanami |
      | Again | ruby         |
    When I request "/sitemap.xml"
    Then the XML answer's "//url/loc" are, in any order:
      | {site}/                   |
      | {site}/about              |
      | {site}/projects           |
      | {site}/contact            |
      | {site}/writing            |
      | {site}/privacy            |
      | {site}/writing/hello      |
      | {site}/writing/again      |
      | {site}/writing/tags/hanami |
      | {site}/writing/tags/ruby  |
    And the XML answer has no "//url/loc[starts-with(substring-after(., '{site}'), '/admin') or starts-with(substring-after(., '{site}'), '/api') or starts-with(substring-after(., '{site}'), '/mcp')]"

  Scenario Outline: The sitemap leaves out <what>
    Given <given>
    When I request "/sitemap.xml"
    Then the XML answer's "//url/loc" are:
      | {site}/         |
      | {site}/about    |
      | {site}/projects |
      | {site}/contact  |
      | {site}/writing  |
      | {site}/privacy  |

    Examples:
      | what                                                  | given                                                     |
      | drafts, scheduled posts and tags only they carry      | a draft and a scheduled post tagged "secret"              |
      | tags only private or archived projects carry          | a private project tagged "secret" and an archived one tagged "retired" |
      | private projects and unpublished boards               | a private project with a published board and a public one without |
      | the admin, API and MCP paths                          | I am not signed in                                        |

  Scenario: The sitemap lists the tags of live public projects
    Given the projects:
      | name    | tags   |
      | Elixirs | elixir |
    When I request "/sitemap.xml"
    Then the XML answer's "//url/loc" include "{site}/writing/tags/elixir"

  Scenario: The sitemap lists a public project's published board, dated by its last change
    Given the projects:
      | name  | board     | updated              |
      | Board | published | 2026-09-04T00:00:00Z |
    When I request "/sitemap.xml"
    Then the XML answer's "//url[loc='{site}/projects/board']/lastmod" is "2026-09-04T00:00:00Z"

  Scenario: The sitemap dates a post by its last change
    Given the posts:
      | title | published            | updated              |
      | Hello | 2026-09-01T00:00:00Z | 2026-09-03T00:00:00Z |
    When I request "/sitemap.xml"
    Then the XML answer's "//url[loc='{site}/writing/hello']/lastmod" is "2026-09-03T00:00:00Z"

  Scenario: The sitemap dates a post by its newest edit note when that is later
    Given the posts:
      | title | published            | updated              |
      | Hello | 2026-09-01T00:00:00Z | 2026-09-01T00:00:00Z |
    And the post "Hello" carries the edit notes:
      | note         | at                   |
      | fixed a typo | 2026-09-05T12:00:00Z |
    When I request "/sitemap.xml"
    Then the XML answer's "//url[loc='{site}/writing/hello']/lastmod" is "2026-09-05T12:00:00Z"
