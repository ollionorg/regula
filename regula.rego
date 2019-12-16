package fugue.regula

import data.util.merge
import data.fugue

# Grab resources from planned values.  Add "id" and "_type" keys.
planned_resources[id] = ret {
  resource = input.planned_values[_].resources[_]
  id = resource.address
  ret = merge.merge(resource.values, {"id": id, "_type": resource.type})
}

# Construct a judgement using results from a single- resource rule.
judgement_from_allow_denies(resource, allows, denies) = ret {
  # Only `allow` is specified and the resource is valid.
  count(allows) > 0
  count(denies) <= 0
  all(allows)
  ret = fugue.allow_resource(resource)
} else = ret {
  # Only `allow` is specified and the resource is invalid.
  count(allows) > 0
  count(denies) <= 0
  not all(allows)
  ret = fugue.deny_resource(resource)
} else = ret {
  # Only `deny` is specified and the resource is valid.
  count(allows) <= 0
  count(denies) > 0
  not any(denies)
  ret = fugue.allow_resource(resource)
} else = ret {
  # Only `deny` is specified and the resource is invalid.
  count(allows) <= 0
  count(denies) > 0
  any(denies)
  ret = fugue.deny_resource(resource)
} else = ret {
  # Both `allow` and `deny` are specified and the resource is valid.
  count(allows) > 0
  count(denies) > 0
  all(allows)
  not any(denies)
  ret = fugue.allow_resource(resource)
} else = ret {
  # Both `allow` and `deny` are specified and the resource is invalid.  This is
  # the only remaining case so the body is very simple.
  count(allows) > 0
  count(denies) > 0
  ret = fugue.deny_resource(resource)
} else = ret {
  # Malformed single-resource rule.
  ret = {
    "error": "The rule does not specify allow or deny."
  }
}

# Evaluate a single rule -- this can be either a single- or a multi-resource
# rule.
evaluate_rule(rule) = ret {
  pkg = rule["package"]
  resource_type = rule["resource_type"]
  resource_type != "MULTIPLE"

  resources = [ j |
    resource = planned_resources[_]
    allows = [a | a = data["rules"][pkg]["allow"] with input as resource]
    denies = [d | d = data["rules"][pkg]["deny"]  with input as resource]
    j = judgement_from_allow_denies(resource, allows, denies)
  ]

  ret = {
    "package": pkg,
    "resources": resources
  }
} else = ret {
  # Note that `rule["resource_type"]` is not specified so we're dealing with a
  # multi-resource type validation.
  pkg = rule["package"]

  policies = [ policy |
    policy = data["rules"][pkg]["policy"] with input as {
      "resources": planned_resources
    }
  ]

  ret = {
    "package": pkg,
    "resources": policies
  }
}

index(rules) = ret {
  ret = [evaluate_rule(rule) | rule = rules[_]]
}
