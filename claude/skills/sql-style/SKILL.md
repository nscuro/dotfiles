---
name: sql-style
description: >-
  My default SQL coding conventions. Use when writing, reviewing, or refactoring SQL.
  This includes migrations, DAO queries, and query strings embedded in code.
  Where the repo's formatter or documented conventions conflict with a rule here, the repo wins.
  All other rules still apply.
---

## Formatting

River style. Right-align clause keywords to a common river, values line up to its right.

* One column per line.
* Leading commas.
* Indent subquery and CTE bodies two spaces past the river.

```sql
with recent_findings as (
  select fnd.component_id
       , fnd.vulnerability_id
    from finding as fnd
   where fnd.created_at >= now() - cast(:max_age as interval)
     and fnd.state != 'SUPPRESSED'
)
select proj.name as project_name
      , count(distinct rf.vulnerability_id) as vulnerability_count
  from project as proj
 inner join component as comp
    on comp.project_id = proj.id
 inner join recent_findings as rf
    on rf.component_id = comp.id
 where proj.inactive_since is null
 group by proj.name
having count(distinct rf.vulnerability_id) >= :min_vulnerability_count
 order by vulnerability_count desc
 limit :limit
```

## Naming

* Tables, columns, CTEs and aliases in lower `snake_case`.
* Never quote identifiers. Name things so quoting is unnecessary.
* Always alias explicitly with `AS`, columns and tables alike.
* Table aliases are short abbreviations, pronounceable, not single letters: `tq`, `dat`, `run`.

## Operators and Types

* `CAST(x AS type)` over `x::type`.
* `!=` over `<>`.
* Named parameters (`:name`) where the DB driver allows it.

## Query Design

* `select exists(select 1 from t where ...)` for existence checks. Never `count(*) > 0`.
* `returning` instead of a follow-up select.
* Prefer one statement over several round trips. CTEs can return several results in one query.
* `where true` followed by `and ...` when predicates are composed conditionally.
* Query shape driven by locking, index choice, or deferred constraints warrants a comment.
