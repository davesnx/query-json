# Feature Request: Multiline Text Input (Textarea)

## Summary

Add a `textarea` or multiline `Text_input` component for editing multiline text with cursor navigation.

## Motivation

While building a REPL interface with mosaic, I needed a text input that can handle multiline queries. The current `Text_input` is explicitly single-line with horizontal scrolling, which works for simple inputs but becomes limiting for:

- Query editors (SQL, jq-style filters, etc.)
- Code snippet inputs
- Multi-line configuration editing
- Any form field where users might want to enter multiple lines

## Current Behavior

`Text_input` documentation states:
> "Text_input provides a focusable single-line text field with cursor navigation... Text_input uses a horizontal scrolling viewport to display text that exceeds available width."

There's no alternative component for multiline editable text.

## Proposed Solution

A `Textarea` or `Text_area` component (or a `~multiline:true` prop on `Text_input`) with:

### Core Features
- Multiple lines of editable text
- Vertical cursor navigation (↑/↓ arrows move between lines)
- Line wrapping (configurable: word, char, or none with horizontal scroll)
- Enter key inserts newline

### Optional/Nice-to-have
- Configurable height (fixed lines or auto-grow)
- Vertical scrolling for content exceeding visible area
- Line numbers (optional)
- Tab handling (insert spaces/tab character or focus navigation)

## API Sketch

```ocaml
val textarea :
  ?autofocus:bool ->
  ?value:string ->
  ?placeholder:string ->
  ?background:Ansi.Color.t ->
  ?text_color:Ansi.Color.t ->
  ?wrap_mode:[ `None | `Word | `Char ] ->
  ?max_lines:int ->
  ?on_input:(string -> 'msg option) ->
  ?on_change:(string -> 'msg option) ->
  ?size:Toffee.Style.dimension Toffee.Geometry.size ->
  unit ->
  'msg t
```

## Alternatives Considered

1. **Building on `Text_surface`** - Could work as a foundation since it already handles text buffers and wrapping, but would require significant custom key handling for editing
2. **External library** - No terminal UI textarea libraries exist for OCaml that integrate with mosaic's architecture
3. **Multiple single-line inputs** - Poor UX, loses the "text as a whole" semantics

## Context

Using mosaic in [query-json](https://github.com/davesnx/query-json) for an interactive REPL. Happy to help with implementation if you can point me in the right direction!

