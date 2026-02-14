-- test_framework.lua - Minimal test runner from the guide
local TestRunner = {
	tests = {},
	passed = 0,
	failed = 0,
	errors = {},
}

function TestRunner.register(name, testFunc)
	table.insert(TestRunner.tests, {
		name = name,
		func = testFunc,
	})
end

function TestRunner.assert_equals(actual, expected, message)
	if actual ~= expected then
		error(
			string.format(
				"%s\n  Expected: %s\n  Got: %s",
				message or "Assertion failed",
				tostring(expected),
				tostring(actual)
			)
		)
	end
end

function TestRunner.assert_true(value, message)
	if not value then
		error(message or "Expected true, got " .. tostring(value))
	end
end

function TestRunner.assert_not_nil(value, message)
	if value == nil then
		error(message or "Expected non-nil value")
	end
end

function TestRunner.run()
	print(string.rep("=", 70))
	print("TEST SUITE")
	print(string.rep("=", 70))
	print()

	for _, test in ipairs(TestRunner.tests) do
		local status, err = pcall(test.func)
		local result = status and "OK" or "FAIL"

		if status then
			TestRunner.passed = TestRunner.passed + 1
			print(string.format("%-50s %s", test.name, result))
		else
			TestRunner.failed = TestRunner.failed + 1
			print(string.format("%-50s %s", test.name, result))
			table.insert(TestRunner.errors, {
				name = test.name,
				error = err,
			})
		end
	end

	print()
	print(string.rep("=", 70))
	print("TEST RESULTS")
	print(string.rep("=", 70))
	print(string.format("Passed: %d", TestRunner.passed))
	print(string.format("Failed: %d", TestRunner.failed))
	print(string.format("Total:  %d", TestRunner.passed + TestRunner.failed))
	print()

	if TestRunner.failed > 0 then
		print("FAILURES:")
		for _, failure in ipairs(TestRunner.errors) do
			print(string.format("\n%s:", failure.name))
			print(failure.error)
		end
		return false
	else
		print("✓ ALL TESTS PASSED")
		return true
	end
end

return TestRunner
