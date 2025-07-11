# Comparison: JSV vs Exdantic

This document compares the structure and design approaches of two Elixir schema validation libraries: JSV (current project) and Exdantic.

## Overview

### JSV
- **Description**: A JSON Schema Validator with complete support for the latest specifications
- **Version**: 0.10.0
- **Focus**: Full JSON Schema specification compliance
- **Files**: 70 Elixir files

### Exdantic
- **Description**: Advanced schema definition and validation library for Elixir
- **Version**: 0.0.2
- **Focus**: Schema DSL with struct generation, inspired by Python's Pydantic
- **Files**: 26 Elixir files

## Architecture Comparison

### JSV Architecture
JSV follows a comprehensive JSON Schema implementation approach:

1. **Vocabulary-based structure**: Organized by JSON Schema versions (v7, v202012)
   - Each version has its own vocabulary modules (validation, applicator, meta_data, etc.)
   - Follows the JSON Schema specification's vocabulary system

2. **Core Components**:
   - `jsv.ex` - Main facade module
   - `builder.ex` - Schema building logic
   - `validator.ex` - Recursive validation engine
   - `resolver.ex` - Reference resolution
   - `ref.ex` - JSON reference handling
   - `vocabulary.ex` - Vocabulary management

3. **Format Validators**: Extensive format validation support
   - Default validators for various formats (email, URI, UUID, etc.)
   - Modular format validator system

4. **Codecs**: Multiple JSON codec support
   - Jason, Poison, and Native codecs
   - Flexible codec system

### Exdantic Architecture
Exdantic follows a DSL-first approach with struct generation:

1. **Schema DSL**: Macro-based schema definition
   - `schema.ex` - DSL for defining schemas
   - `field_meta.ex` - Field metadata management
   - Struct generation capabilities

2. **Core Components**:
   - `exdantic.ex` - Main module with examples and documentation
   - `validator.ex` - Validation logic
   - `struct_validator.ex` - Struct-specific validation
   - `type_adapter.ex` - Type conversion and adaptation

3. **Runtime System**:
   - `runtime/` - Dynamic schema handling
   - `enhanced_validator.ex` - Enhanced validation features
   - `dynamic_schema.ex` - Runtime schema creation

4. **JSON Schema Support**:
   - `json_schema.ex` - JSON Schema generation from Exdantic schemas
   - `json_schema/` - Supporting modules for JSON Schema features

## Key Differences

### 1. Design Philosophy
- **JSV**: Standards-compliant JSON Schema validator
  - Implements the full JSON Schema specification
  - Vocabulary-based architecture mirrors the spec
  - Focus on correctness and completeness

- **Exdantic**: Developer-friendly schema DSL
  - Inspired by Python's Pydantic
  - Focus on ergonomics and ease of use
  - Generates structs alongside validation

### 2. Schema Definition
- **JSV**: JSON Schema format (maps with keywords)
  ```elixir
  %{
    type: :object,
    properties: %{
      name: %{type: :string}
    }
  }
  ```

- **Exdantic**: DSL with macros
  ```elixir
  schema do
    field :name, :string do
      required()
      min_length(2)
    end
  end
  ```

### 3. Validation Approach
- **JSV**: 
  - Recursive validator with context tracking
  - Supports all JSON Schema keywords
  - Detailed error paths and evaluation tracking

- **Exdantic**:
  - Field-by-field validation
  - Constraint-based validation
  - Struct validation support

### 4. Feature Set
- **JSV**:
  - Complete JSON Schema draft support (v7, v202012)
  - Reference resolution ($ref)
  - Format validation
  - Unevaluated properties handling
  - Content validation

- **Exdantic**:
  - Struct generation
  - Computed fields
  - Type adapters
  - JSON Schema export
  - Configuration system

### 5. Error Handling
- **JSV**:
  - Detailed validation errors with paths
  - Error formatting utilities
  - Schema and data path tracking

- **Exdantic**:
  - Structured validation errors
  - Field-level error reporting
  - Error accumulation

## Use Case Alignment

### When to use JSV:
- Need full JSON Schema specification compliance
- Working with external JSON Schema definitions
- Interoperability with other JSON Schema tools
- Complex schema validation with references

### When to use Exdantic:
- Building Elixir applications with structured data
- Want struct generation from schemas
- Prefer DSL-based schema definition
- Need computed fields and custom validations

## Maturity and Scope

- **JSV** (v0.10.0): More mature, focused on JSON Schema specification
- **Exdantic** (v0.0.2): Early stage, focused on developer experience

Both libraries serve different needs in the Elixir ecosystem, with JSV providing standards compliance and Exdantic offering a more Elixir-idiomatic approach to schema validation.