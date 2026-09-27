extends "res://scripts/platform_services.gd"
## Only loaded by --self-test, never used by the release reward adapter.
var success := false
var calls := 0

func is_rewarded_available() -> bool:
	return true

func request_rewarded(_placement: String) -> bool:
	calls += 1
	return success
