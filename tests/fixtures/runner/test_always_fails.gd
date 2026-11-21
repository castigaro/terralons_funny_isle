extends TestCase
## Runner self-test fixture: always fails, so the runner must exit non-zero.


func test_deliberate_failure() -> void:
	fail("deliberate")
