# Vocabularies

JSV follows the JSON Schema Draft 2020-12 specification, which uses the
vocabulary system to define the capabilities of schemas.

Future releases of JSV will allow defining custom vocabularies, but for now, JSV
only uses a fixed set of schema keyword implementations.


## Meta-schemas: Introduction to vocabularies

> ### Note {: .tip}
>
> You can skip this section if you are not interested in the inner workings of
> the JSON Schema specification.

Here is what happens when validating with the latest specification:


### The well-known and official schema

The `https://json-schema.org/draft/2020-12/schema` schema defines the following
vocabulary:

```json
{
  "$vocabulary": {
    "https://json-schema.org/draft/2020-12/vocab/core": true,
    "https://json-schema.org/draft/2020-12/vocab/applicator": true,
    "https://json-schema.org/draft/2020-12/vocab/unevaluated": true,
    "https://json-schema.org/draft/2020-12/vocab/validation": true,
    "https://json-schema.org/draft/2020-12/vocab/meta-data": true,
    "https://json-schema.org/draft/2020-12/vocab/format-annotation": true,
    "https://json-schema.org/draft/2020-12/vocab/content": true
  }
}
```

The vocabulary is split into different parts, here one by object property. More
information can be found on the [official
website](https://json-schema.org/learn/glossary#vocabulary).


### $schema declaration

The well-known schema can be used as a meta-schema. This is done by using its
URI as the `$schema` property of the inheriting schema.

We would like to use the `type` keyword to validate some data. To let the
library know what keywords should be handled, our schema declares the
`https://json-schema.org/draft/2020-12/schema` as its meta-schema using the
`$schema` keyword.

```json
  {
    "$schema": "https://json-schema.org/draft/2020-12/schema",
    "type": "integer"
  }
```

JSV will use `https://json-schema.org/draft/2020-12/schema` if the `$schema`
property is not defined in your schemas.

Vocabularies have limitations:

* If you declare both `$schema` and `$vocabulary` in your schema, another schema
  using yours as its meta-schema will only use your `$vocabulary`, and not the
  one of the referenced `$schema`.
* You cannot declare a `$vocabulary` property in your schema and expect it to be
  used and/or override those of the meta-schema. It will only be used by another
  schema referencing your own as its `$schema`.


### Implementation in libraries and tools

Libraries such as JSV must map this vocabulary to implementations.

Be aware that the `true` values in the `$vocabulary` keyword do not mean
"enabled" but "enforced". A `false` value allows libraries to skip the
vocabulary if they do not implement it.

For instance, in JSV, the
`https://json-schema.org/draft/2020-12/vocab/validation` part that defines the
`type` keyword is implemented with the `JSV.Vocabulary.V202012.Validation`
Elixir module.

As JSV is compliant, it will use this implementation to validate data types.

On the other hand, if that vocabulary is not declared in your meta-schema, **the
`type` keyword will not be used**, as with any other keyword declared by the
[validation vocabulary](https://json-schema.org/draft/2020-12/vocab/validation).
