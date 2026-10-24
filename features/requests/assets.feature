Feature: Assets
  Assets carry a fingerprint in their name, so browsers and Cloudflare keep them for a year. A miss and the
  manifest stay out of every cache.

  Scenario Outline: <source> has a fingerprinted name that caches for a year
    When I request "{asset:<source>}"
    Then it answers 200
    And the path I asked for matches "^/assets/.+-[A-Z0-9]{8}\.\w+$"
    And the "Cache-Control" header is "public, max-age=31536000, immutable"

    Examples:
      | source        |
      | public/app.css |
      | admin/app.css |
      | app.js        |
      | favicon.svg   |

  Scenario: A fingerprinted name that is not there answers 404 and stays out of every cache
    When I request "/assets/app-AAAAAAAA.css"
    Then it answers 404
    And there is no "Cache-Control" header

  Scenario: The manifest is served and stays out of every cache
    When I request "/assets/assets.json"
    Then it answers 200
    And there is no "Cache-Control" header
