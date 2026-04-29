Feature: Items end-to-end
  Drives the UI via Playwright, which hits the Scala backend.
  Validates the full stack in one pass.

  @smoke
  Scenario: Backend health check
    Given the backend is reachable
    Then the health endpoint returns ok

  @smoke
  Scenario: API create and list
    When I POST an item named "thingamajig"
    Then GET /api/items includes "thingamajig"

  @ui
  Scenario: UI adds an item end-to-end
    When I open the UI
    And I add an item named "gadget" via the UI
    Then the item "gadget" appears in the list

  @flaky
  Scenario: Occasionally flaky — UI render timing
    When I open the UI
    Then the heading "Items" eventually appears

  # Showcase scenarios — purely to give the reporter a richer dataset
  # (varied p95s, retries, skips). No real product behavior exercised.

  @perf
  Scenario Outline: Workload duration buckets — <size>
    When a <size> workload runs
    Then it returns within budget

    Examples:
      | size    |
      | fast    |
      | medium  |
      | slow    |
      | glacial |

  @flaky @network
  Scenario: Network jitter retries cleanly
    When a request is sent with intermittent network jitter
    Then the response is eventually successful

  @wip
  Scenario: Pending feature — surfaced in Skipped report
    Given the backend is reachable
    Then the health endpoint returns ok
