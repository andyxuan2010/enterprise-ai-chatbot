#!/usr/bin/env bash

set -euo pipefail

plan_file="${1:?terraform plan file path is required}"
summary_label="${2:-Terraform change summary}"

if [[ ! -f "${plan_file}" ]]; then
  echo "Terraform plan file not found: ${plan_file}" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to generate the Terraform change summary." >&2
  exit 1
fi

terraform show -json "${plan_file}" | jq -r --arg label "${summary_label}" '
  def category($actions):
    if $actions == ["create"] then "add"
    elif $actions == ["update"] then "change"
    elif $actions == ["delete"] then "destroy"
    elif (($actions | index("create")) and ($actions | index("delete"))) then "change"
    else "change"
    end;

  def is_replace($actions):
    (($actions | index("create")) and ($actions | index("delete")));

  def summarize($items; $name):
    ($items | length) as $count
    | if $count == 0 then
        "\($name): 0"
      else
        ($items
        | group_by(.type)
        | map({type: .[0].type, count: length})
        | sort_by(-.count, .type)
        | .[:3]
        | map("\(.type) x\(.count)")
        | join(", ")) as $types
        | "\($name): \($count) | \($types)"
      end;

  [
    .resource_changes[]?
    | select(.change.actions != ["no-op"])
    | {
        type: .type,
        category: category(.change.actions),
        replace: is_replace(.change.actions)
      }
  ] as $changes
  | if ($changes | length) == 0 then
      [
        $label,
        "Add: 0",
        "Change: 0",
        "Destroy: 0",
        "Result: no changes"
      ]
    else
      [
        $label,
        summarize(($changes | map(select(.category == "add"))); "Add"),
        summarize(($changes | map(select(.category == "change"))); "Change"),
        summarize(($changes | map(select(.category == "destroy"))); "Destroy")
      ] + (
        ($changes | map(select(.replace)) | length) as $replace_count
        | if $replace_count > 0 then
            ["Recreate: \($replace_count)"]
          else
            []
          end
      )
    end
  | .[]
'
