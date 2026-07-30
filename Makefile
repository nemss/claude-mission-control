.PHONY: test health

# Hook test suite. validate-task.sh detects this target, which is what makes the
# TaskCompleted quality gate actually run something for this project.
test:
	@bash .claude/hooks/tests/run-tests.sh

# System integrity check (directories, agents, skills, hooks, memory format).
health:
	@bash .claude/hooks/health-check.sh
