# ctx-core JSON Contract (schema_version=1)

Every response is JSON and includes `schema_version`.

## Success
```json
{
  "schema_version": 1,
  "ok": true,
  "data": {}
}
```

## Failure
```json
{
  "schema_version": 1,
  "ok": false,
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable message",
    "details": {}
  }
}
```

## Commands
- `capture`: returns `data.capture`
- `lookup`: returns `data.file_hash`, `data.records`, `data.count`
- `search`: returns `data.query`, `data.backend`, `data.results`, `data.count`

## Compatibility rule
- Additive fields are allowed without bumping major behavior.
- Breaking shape changes require a new `schema_version`.
