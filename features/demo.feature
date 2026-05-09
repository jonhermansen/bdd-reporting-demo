Feature: Chaos test suite
  Every scenario hits a local chaos HTTP server that randomly
  drops connections, times out, returns errors, or responds
  slowly. Run with --retry and --parallel to surface flaky
  tests and create interesting concurrency patterns.

  @flaky
  Scenario: Login flow
    Given a service
    When the login flow runs
    Then it completes

  @flaky
  Scenario: Search query
    Given a service
    When a search runs
    Then it completes

  @flaky
  Scenario: Checkout
    Given a service
    When checkout runs
    Then it completes

  @flaky
  Scenario: File upload
    Given a service
    When a file upload runs
    Then it completes

  @flaky
  Scenario: Report generation
    Given a service
    When report generation runs
    Then it completes

  @flaky
  Scenario: Notification dispatch
    Given a service
    When notification dispatch runs
    Then it completes

  @flaky
  Scenario: Data sync
    Given a service
    When data sync runs
    Then it completes

  @flaky
  Scenario: Cache warmup
    Given a service
    When cache warmup runs
    Then it completes

  @flaky
  Scenario Outline: Batch job — <batch>
    Given a service
    When batch <batch> runs
    Then it completes

    Examples:
      | batch       |
      | etl-users   |
      | etl-orders  |
      | etl-events  |
      | etl-metrics |
      | reindex     |
      | gc-old-data |

  @flaky
  Scenario Outline: Health probe — <target>
    Given a service
    When health probe hits <target>
    Then it completes

    Examples:
      | target   |
      | postgres |
      | redis    |
      | kafka    |
      | s3       |
