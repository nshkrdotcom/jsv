# Test Guide: Lessons from 6,411 Tests

This guide documents the testing strategy that achieved comprehensive coverage with 6,411 tests across 337 test files in this Elixir JSON Schema Validator codebase.

## The Secret: Test Generation and Multiplication

The key insight that enabled this massive test coverage is **automated test generation with representation multiplication**. Here's how it works:

### 1. Leverage External Test Suites

Instead of writing thousands of tests manually, this project:
- Uses the official JSON Schema Test Suite as a git dependency
- Generates Elixir test files from the JSON test cases
- Automatically stays compliant with the specification

**Lesson**: Don't reinvent the wheel. If an authoritative test suite exists for your domain, use it.

### 2. The Multiplication Strategy

Each test from the JSON Schema Test Suite is run in three different contexts:
- **BinaryKeys**: Standard JSON with string keys
- **AtomKeys**: Using Elixir atoms (for JSV.Schema structs)
- **DecimalValues**: Testing with Decimal number support

This transforms ~2,000 base tests into 6,000+ tests, ensuring the validator works correctly across different data representations.

**Lesson**: Test your core functionality with different input/output representations relevant to your language/framework.

## How to Build Comprehensive Test Coverage

### Step 1: Identify Your Testing Dimensions

For this JSON Schema validator, the dimensions were:
- **Specification versions** (Draft 7, Draft 2020-12)
- **Data representations** (binary keys, atom keys, decimal values)
- **Optional features** (formats, bignum support)
- **Error conditions** (validation failures, build errors)

**Action**: List all the dimensions that affect your system's behavior.

### Step 2: Create a Test Generation Infrastructure

```elixir
# Example from dev/gen.test.suite.ex
defmodule GenTestSuite do
  def generate_tests(test_suite_path, output_dir) do
    # 1. Parse external test suite
    # 2. Generate test modules for each dimension
    # 3. Create consistent test structure
  end
end
```

**Components needed**:
- Test parser (reads external test format)
- Template engine (generates test code)
- Configuration system (include/exclude features)
- Mix task for regeneration

### Step 3: Establish Testing Patterns

#### Generated Test Pattern
```elixir
defmodule JSV.Generated.Draft7.AdditionalPropertiesTest do
  use ExUnit.Case, async: true
  
  describe "additionalProperties with boolean" do
    setup do
      schema = build_schema(%{"additionalProperties" => true})
      {:ok, schema: schema}
    end
    
    test "accepts any additional properties", %{schema: schema} do
      assert {:ok, _} = validate(schema, %{"foo" => "bar"})
    end
  end
end
```

#### Manual Test Pattern
```elixir
defmodule JSV.BuilderTest do
  use ExUnit.Case, async: true
  
  test "builds schema with custom vocabulary" do
    # Specific implementation tests
  end
end
```

### Step 4: Organize Your Tests

```
test/
├── jsv/                    # Core functionality tests
│   ├── builder_test.exs
│   ├── error_formatter_test.exs
│   └── ...
├── jsv/generated/          # Auto-generated tests
│   ├── draft7/
│   ├── draft2020-12/
│   └── ...
└── support/               # Test helpers
    ├── json_schema_suite.ex
    └── test_resolver.ex
```

### Step 5: Test Multiple Layers

1. **Specification Compliance** (via generated tests)
   - Ensures correct implementation of the standard
   - Covers all edge cases defined by the spec

2. **Unit Tests** (manually written)
   - Internal APIs and helpers
   - Language-specific features
   - Performance-critical paths

3. **Integration Tests**
   - HTTP resolvers with mocking
   - File system operations
   - Error propagation

4. **Error Path Testing**
   - Build-time errors
   - Validation errors
   - Error formatting

## Practical Implementation Guide

### 1. Start with Test Infrastructure

Create a robust test helper module:

```elixir
defmodule TestHelper do
  def run_validation_test(schema, data, expected_result) do
    result = JSV.validate(schema, data)
    assert_validation_result(result, expected_result)
  end
  
  def assert_validation_result({:ok, _}, true), do: :ok
  def assert_validation_result({:error, _}, false), do: :ok
  def assert_validation_result(result, expected) do
    flunk("Expected #{expected}, got #{inspect(result)}")
  end
end
```

### 2. Use Async Tests Wherever Possible

```elixir
use ExUnit.Case, async: true  # Default for most tests

# Only use sync for:
use ExUnit.Case, async: false  # HTTP/external resource tests
```

### 3. Mock External Dependencies

```elixir
test "fetches remote schema" do
  Patch.patch(HTTPClient, :get, fn url ->
    {:ok, %{status: 200, body: ~s({"type": "string"})}}
  end)
  
  # Test with mocked HTTP
end
```

### 4. Create a Test Generation Pipeline

```bash
# Mix task to regenerate tests
mix gen.test.suite

# Configuration in config/test.exs
config :jsv_test_suite,
  skip_tests: ["optional/format/idn-hostname"],
  test_dimensions: [:binary_keys, :atom_keys, :decimal_values]
```

### 5. Maintain Test Quality

- **Clear test names**: Each test should describe what it validates
- **Isolated tests**: No shared state between tests
- **Fast execution**: Use async and avoid real I/O
- **Deterministic**: Same result every time
- **Documented**: Include references to specifications

## Scaling Test Coverage

### For 1,000+ Tests
- Invest in test generation early
- Use consistent patterns
- Parallelize test execution
- Group related tests in modules

### For 5,000+ Tests
- Implement test filtering/tagging
- Create specialized test runners
- Monitor test execution time
- Use CI parallelization

### For 10,000+ Tests
- Consider test sampling for quick feedback
- Implement incremental test runs
- Use test impact analysis
- Distribute tests across multiple machines

## Key Takeaways

1. **Multiplication is Powerful**: Test the same functionality across different dimensions
2. **Generation Beats Manual**: Automate test creation where possible
3. **Structure Matters**: Organize tests logically for maintainability
4. **External Suites Add Value**: Leverage existing test suites in your domain
5. **Consistency Enables Scale**: Use patterns that work at 10 tests and 10,000 tests

## Checklist for Your Project

- [ ] Identify authoritative test suites in your domain
- [ ] List all behavioral dimensions of your system
- [ ] Create test generation infrastructure
- [ ] Establish consistent test patterns
- [ ] Implement test helpers for common operations
- [ ] Set up mocking for external dependencies
- [ ] Configure async test execution
- [ ] Create Mix tasks for test maintenance
- [ ] Document your testing strategy
- [ ] Monitor and optimize test execution time

By following these patterns, you can build and maintain comprehensive test coverage that scales with your codebase while ensuring quality and specification compliance.