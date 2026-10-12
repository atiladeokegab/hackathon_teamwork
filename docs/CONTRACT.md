# Contract

Written by the lead's agent at the start of the build, from the day spec. Every area builds against
it; only the lead changes it (anything else is a change-request, AGENTS.md §6).

## Assignment

<The event's task, quoted from the brief, then the one-line demo from IDEA.md.>

## Shared core

What every area uses and nobody re-implements (AGENTS.md §1):

| Piece | Where | Use it for |
|---|---|---|
| App factory | `starter/runtime/factory.py`, `create_app()` | every router and page |
| Store | `starter/core/store.py`: `snapshot()`, `mutate(fn)`, `publish(event)` | all state |
| Gateway | `starter/core/gateway.py` | every tool call and external effect |
| Runner | `scripts/run_cases.py` | cases in, `ANSWERS/` out |

## Shapes

<One block per shared record: name, fields with types, an example, the owning area.>

## HTTP

- Errors: 409 conflict, 404 not found, 422 bad input (`ValueError`), 503 provider not configured.
- Every request is logged with a trace id.
- <One line per endpoint: method, path, request shape, response shape, owning area.>

## Gateway tools

<One line per tool: name, input, output, the effect it performs or simulates (`SIMULATED`), owning area.>

<How each vertical's tool reaches the current case: the gateway passes a tool only its arguments, and
a `SIMULATED` effect runs only in its `simulate=` hook. Say which input or hook carries the case.>

## Answers

`ANSWERS/<n>/ANSWER.md` in the event's format, with one line `Final state: <STATE>`, where STATE is
one of: <the event's final states, e.g. DONE | ESCALATED | NEEDS_INFO>. Only the runner writes `ANSWERS/`.

## Check

`make check` (ruff and pytest) and the smoke in HACKATHON.md. <The contract tests that pin these shapes.>
