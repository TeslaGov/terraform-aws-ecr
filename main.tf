locals {
  defaults = {
    scan_on_push = true
    # The tag mutability setting for the repository. Must be one of: MUTABLE or IMMUTABLE. Defaults to MUTABLE.
    image_tag_mutability = "MUTABLE"
  }
}

resource "aws_ecr_repository" "this" {

  for_each = { for k, v in var.ecrs : k => v }

  name                 = each.key
  image_tag_mutability = try(each.value.image_tag_mutability, local.defaults.image_tag_mutability)

  image_scanning_configuration {
    scan_on_push = try(each.value.scan_on_push, local.defaults.scan_on_push)
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(var.tags, try(each.value.tags, null))
}

# lifecycle policy, to make sure we don’t keep too many versions of image,
# as with every new deployment of the application, a new image would be created.
resource "aws_ecr_lifecycle_policy" "this" {

  for_each = { for k, v in var.ecrs : k => v if lookup(v, "lifecycle_policy", null) != null
  && try(length(v.lifecycle_policy) > 0, false) }

  repository = aws_ecr_repository.this[each.key].id
  policy     = jsonencode(each.value.lifecycle_policy)

  depends_on = [aws_ecr_repository.this]
}

# repository resource policy
# this is optional and allows you to set additional restrictions/perms at the repo level
# in addition to setting IAM perms at the user/group level
data "aws_iam_policy_document" "this" {
  for_each = { for k, v in var.ecrs : k => v if lookup(v, "repository_policy", null) != null
  && try(length(v.repository_policy) > 0, false) }

  statement {
    actions   = each.value.repository_policy.statement.actions
    resources = each.value.repository_policy.statement.resources
    principals {
      type        = each.value.repository_policy.statement.principals.type
      identifiers = each.value.repository_policy.statement.principals.identifiers
    }
  }
}

resource "aws_ecr_repository_policy" "this" {
  for_each = { for k, v in var.ecrs : k => v if lookup(v, "repository_policy", null) != null
  && try(length(v.repository_policy) > 0, false) }

  repository = aws_ecr_repository.this[each.key].name
  policy     = data.aws_iam_policy_document.this[each.key].json
}
