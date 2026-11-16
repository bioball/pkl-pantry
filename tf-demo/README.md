# Demo of using Pkl with OpenTofu/Terraform

This is a simple example of using Pkl as a DSL for OpenTofu/Terraform.

There's two projects here:

* simple - a "real world" example of using Pkl to define IaC. This repo has two versions of the same logical program:
  * `simple/main.pkl` - the Pkl version of the program
  * `simple/main.tofu` - the HCL version of the program

* symbol-libraries - the Pkl port of the example from https://opentofu.org/blog/2026/09/17/symbol-libraries-introduction/.

## Why Pkl?

HCL is a mostly static language that trades predicability for expressivity.
This has been a pain point for users; for example, it's hard to DRY up code because HCL itself doesn't have imports.

To drive Terraform/OpenTofu, there have been many tools that have been created focused on adding expressivity to TF programs, but they generally are still defined as static HCL that gets executed by an external engine (e.g. symbol libraries, Terragrunt).

Both of these approaches are more or less inventing a new programming language bound by the syntax of HCL.
This tends to lead to code that is awkward to write and understand.

On the other hand, Pkl is a blend of a configuration language _and_ a programming language.
The Pkl evaluator executes the logic defined in a program, and produces a result.
Any logic is intrinsic to Pkl itself, which is understood by the Pkl evaluator and its suite of tooling (IDE, linting, formatting, tests, and more).

The Pkl language is:

* Type-safe: there are type annotations, classes, typealiases, and a powerful type system.
* Sandboxed: users can control Pkl programs are allowed to do during the course of evaluation.
* Short-lived: a program executes to completion and produces a result.
* Hermetic: the same inputs always produce the same outputs.
* Expressive: control flow statements like `if/else` expressions, for loops, module imports, user-defined types, and more.
* Metaprogramming oriented: You can write code that generates Pkl from something else, or generate something else from Pkl (think HCL → Pkl generator, Pkl → HCL generator).
* Full-featured: the standard library contains support for testing, benchmarking, packaging, dependencies, and more.

## Requirements

* `pkl` CLI

    ```
    brew install pkl
    ```

    Or see https://pkl-lang.org/main/current/pkl-cli/index.html#installation for more options
* IDE editor with the Pkl plugin installed
  * [IntelliJ](https://pkl-lang.org/intellij/current/installation.html)
  * [Neovim](https://pkl-lang.org/neovim/current/installation.html)
  * [VSCode](https://pkl-lang.org/vscode/current/installation.html)
* `tofu` or `terraform` CLI

## Quick start

1. Open this repo in your IDE.
2. Run the "sync projects" action so the editor picks up dependencies.
3. Run `pkl eval main.pkl` for either of these two examples to see the JSON output.

## Generating schemas

In order to provide completions, type checking, etc., there is a code generator that takes a TF project, and generates the corresponding schemas for Pkl.

To do this, run:

```bash
# go to the simple project
cd simple/

# initialize the project 
tofu init

# generate the schemas
tofu providers schema -json | pkl run @tf.codegen/init.pkl
```

The generated schemas for this example are already checked in, but you can play around with adding another provider and generating more stuff.

## Features

### Computed value support

Pkl understands the concept of "unknown" values, through its `Reference<Domain, Type>` type.
This example uses references to keep track of unknown values and their types, at arbitrary nesting levels.
For more details about references, read through https://pkl-lang.org/main/current/release-notes/0.32.html#new-data-type-reference.

This wraps references as `tf.Computed<T>` (a typealias for the underlying reference within the TF domain).
It's an error to give a `tf.Computed<Boolean>` to something that expects an integer.

### Core tf and provider functions

Through references, we can model calling a TF function as a regular Pkl function.

### Regular Pkl features

Because Pkl is a full language, there's no need to create new HCL rules.
For example, Pkl already has functions, for loops, types, imports, etc.

The three examples from the symbol libraries blog post are all just regular constructs that Pkl just provides.
This includes type validation logic like "length != 0".
Pkl has an incredible type system, including union types, string literals, and type constraints.

### Completions/Documentation

Having generated code means that users can cmd + click from a property to its definition, see its doc comments, and more. 

### Linting/Analysis

Beyond just type checking, the editors also analyze Pkl code and give warnings/hints about possibly problematic code, or refactorings to make code simpler.

### Packages/Projects

Pkl comes with the concept of packages and projects.
You can create a package that has dependencies, and publish them somewhere.
You can also create a project that uses those package as dependencies.

## Evaluation

Right now, this just produces `.tf.json` style JSON that OpenTofu/Terraform accept.

However, Pkl also has many other ways of driving evaluation.
Notably, you can evaluate this stuff into structs and interfaces directly in Go via the [pkl-go](https://github.com/apple/pkl-go) library.
This includes references, which gives you the pathing data for any computed value.

## Future directions

These are not in this demo but are possible future directions:

* HCL → Pkl migrator

  A tool that parses HCL and turns it into the semantic equivalent in Pkl.

* Terraform/Tofu first-party integration

  Baking Pkl into `tofu init`, and generating Pkl schemas automatically.

* Control flow / operator support with computed values

  It doesn't make sense to use basic control flow with computed values (because Pkl doesn't know what the underlying value are).
  Some possible solutions are either via multi-shot evaluation, or encoding logic in an in-language "DSL".
