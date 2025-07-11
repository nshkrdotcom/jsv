# Exploration: JSV and Exdantic Complementary Use Cases

This document explores how JSV and Exdantic can complement each other in real-world applications, both through direct integration in smaller system components and indirect collaboration in larger distributed systems.

## Executive Summary

JSV and Exdantic serve different but complementary roles in the Elixir ecosystem:
- **JSV**: Standards-compliant JSON Schema validator, ideal for API boundaries and external data validation
- **Exdantic**: Developer-friendly schema DSL with struct generation, ideal for internal domain modeling

Rather than competing, these libraries can work together to provide comprehensive data validation across different layers of an application.

## Direct Integration Use Cases

### 1. API Gateway Pattern
In this pattern, JSV validates external data at the API boundary, while Exdantic manages internal domain models:

```elixir
defmodule MyApp.API.UserController do
  # JSV validates incoming JSON against OpenAPI schema
  def create(conn, params) do
    case JSV.validate(params, jsv_schema()) do
      {:ok, valid_data} ->
        # Transform to internal domain model using Exdantic
        case UserSchema.validate(valid_data) do
          {:ok, user_struct} ->
            # Work with strongly-typed struct
            MyApp.create_user(user_struct)
          {:error, errors} ->
            # Handle domain validation errors
        end
      {:error, errors} ->
        # Handle JSON Schema validation errors
    end
  end
end
```

**Benefits:**
- JSV ensures API contract compliance
- Exdantic provides rich domain modeling
- Clear separation between external and internal validation

### 2. Configuration Management
Use JSV for configuration file validation and Exdantic for runtime configuration structs:

```elixir
defmodule MyApp.Config do
  # Define internal config structure with Exdantic
  use Exdantic, define_struct: true
  
  schema do
    field :database_url, :string do
      required()
    end
    field :port, :integer do
      default(4000)
      gte(1)
      lte(65535)
    end
  end
  
  # Load and validate config file
  def load_from_file(path) do
    with {:ok, json} <- File.read(path),
         {:ok, data} <- Jason.decode(json),
         {:ok, validated} <- JSV.validate(data, config_schema()),
         {:ok, config} <- __MODULE__.validate(validated) do
      {:ok, config}
    end
  end
end
```

**Benefits:**
- JSV validates JSON/YAML config files
- Exdantic provides typed configuration structs
- Runtime type safety for configuration

### 3. Data Pipeline Validation
In ETL or data processing pipelines, use both libraries at different stages:

```elixir
defmodule DataPipeline do
  # Stage 1: Validate raw input with JSV
  def ingest(raw_data) do
    JSV.validate(raw_data, input_schema())
  end
  
  # Stage 2: Transform to domain model with Exdantic
  def transform(validated_data) do
    TransformedData.validate(validated_data)
  end
  
  # Stage 3: Validate output format with JSV
  def export(domain_struct) do
    domain_struct
    |> TransformedData.dump()
    |> JSV.validate(output_schema())
  end
end
```

**Benefits:**
- JSV ensures data conforms to external formats
- Exdantic manages internal transformations
- Clear validation at each pipeline stage

## Indirect System-Level Patterns

### 1. Microservices Architecture
Different services can choose the appropriate tool based on their needs:

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│   Public API    │     │  Internal API   │     │  Domain Service │
│  Service (JSV)  │────▶│ Gateway (Both)  │────▶│   (Exdantic)    │
└─────────────────┘     └─────────────────┘     └─────────────────┘
```

- **Public API Service**: Uses JSV for OpenAPI/JSON Schema compliance
- **Internal API Gateway**: Uses JSV for external validation, Exdantic for routing
- **Domain Services**: Use Exdantic for rich domain modeling

### 2. Event-Driven Architecture
In event-sourced or CQRS systems:

```elixir
# Event definitions use Exdantic for internal structure
defmodule UserCreatedEvent do
  use Exdantic, define_struct: true
  
  schema do
    field :user_id, :string
    field :email, :string
    field :created_at, :datetime
  end
end

# Event store validates with JSV for persistence
defmodule EventStore do
  def append(event) do
    event_data = 
      event
      |> struct_to_map()
      |> Map.put("$type", event.__struct__)
    
    # Validate against event schema for storage
    case JSV.validate(event_data, event_schema()) do
      {:ok, _} -> persist(event_data)
      error -> error
    end
  end
end
```

### 3. GraphQL + REST Hybrid
Use appropriate validation for each API style:

```elixir
# GraphQL resolver uses Exdantic
defmodule MyApp.GraphQL.UserResolver do
  def create_user(_, args, _) do
    case UserSchema.validate(args) do
      {:ok, user} -> {:ok, create(user)}
      {:error, errors} -> {:error, format_graphql_errors(errors)}
    end
  end
end

# REST controller uses JSV
defmodule MyApp.REST.UserController do
  def create(conn, params) do
    case JSV.validate(params, user_json_schema()) do
      {:ok, data} -> create_user(data)
      {:error, errors} -> {:error, format_rest_errors(errors)}
    end
  end
end
```

## Migration and Interoperability Patterns

### 1. Progressive Migration
Teams can gradually adopt one tool while maintaining the other:

```elixir
defmodule MigrationHelper do
  # Convert Exdantic schema to JSON Schema for JSV
  def exdantic_to_json_schema(module) do
    module.__json_schema__()
  end
  
  # Generate Exdantic module from JSON Schema
  def json_schema_to_exdantic(json_schema, module_name) do
    # Code generation logic
  end
end
```

### 2. Schema Registry Pattern
Maintain a central schema registry that serves both formats:

```elixir
defmodule SchemaRegistry do
  def get_schema(name, :json_schema), do: fetch_json_schema(name)
  def get_schema(name, :exdantic), do: fetch_exdantic_module(name)
  
  def register_schema(name, exdantic_module) do
    store_exdantic(name, exdantic_module)
    store_json_schema(name, exdantic_module.__json_schema__())
  end
end
```

## Best Practices for Combined Usage

### 1. Clear Boundaries
- Use JSV at system boundaries (APIs, files, external data)
- Use Exdantic for internal domain modeling
- Document which validation applies where

### 2. Consistent Error Handling
Create adapters to normalize error formats:

```elixir
defmodule ValidationError do
  def normalize({:error, %JSV.ValidationError{} = error}), do: normalize_jsv(error)
  def normalize({:error, errors}) when is_list(errors), do: normalize_exdantic(errors)
end
```

### 3. Performance Considerations
- JSV is optimized for complex schema validation
- Exdantic is optimized for struct creation and simple validations
- Choose based on performance requirements

### 4. Testing Strategy
```elixir
# Test external contracts with JSV
test "API response matches schema" do
  response = MyAPI.get_user(123)
  assert {:ok, _} = JSV.validate(response, user_schema())
end

# Test domain logic with Exdantic
test "user creation with valid data" do
  assert {:ok, %User{} = user} = User.validate(%{name: "Alice", age: 30})
  assert user.name == "Alice"
end
```

## Conclusion

JSV and Exdantic serve complementary roles in the Elixir ecosystem:

- **JSV** excels at standards-compliant validation, making it ideal for:
  - API boundaries
  - Configuration files
  - Data interchange formats
  - OpenAPI/JSON Schema compliance

- **Exdantic** excels at developer-friendly domain modeling, making it ideal for:
  - Internal domain models
  - Struct-based workflows
  - Computed fields and business logic
  - Rapid development with DSLs

By understanding where each tool shines, teams can leverage both libraries to build robust, well-validated applications that maintain clean boundaries between external interfaces and internal domain models.