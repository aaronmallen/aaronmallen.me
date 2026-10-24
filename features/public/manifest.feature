Feature: Web manifest
  The web manifest names the site after its owner and lists the app icons by their fingerprinted names.

  Scenario: The manifest answers as a web manifest with the icons, cached five minutes
    When I request "/site.webmanifest"
    Then the "Content-Type" header starts with "application/manifest+json"
    And the "Cache-Control" header is "public, max-age=0, s-maxage=300"
    And the JSON answer holds "icons" as "[{\"src\":\"{asset:icon-192.png}\",\"sizes\":\"192x192\",\"type\":\"image/png\"},{\"src\":\"{asset:icon-512.png}\",\"sizes\":\"512x512\",\"type\":\"image/png\"}]"
    And the JSON answer holds "name" as "Aaron Allen"
    And the JSON answer holds "short_name" as "Aaron Allen"

  Scenario: The manifest answers a browser that accepts anything
    Given my requests send the header "Accept" as "*/*"
    When I request "/site.webmanifest"
    Then the "Content-Type" header starts with "application/manifest+json"

  Scenario: The manifest stays out of shared caches while the owner is signed in
    Given I am signed in to the admin
    When I request "/site.webmanifest"
    Then the "Cache-Control" header does not include "s-maxage"
