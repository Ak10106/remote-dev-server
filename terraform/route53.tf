# ============================================
# Route53 Hosted Zone (Optional)
# ============================================

resource "aws_route53_zone" "main" {
  count = var.create_route53_zone ? 1 : 0

  name    = var.root_domain_name
  comment = "Managed by Terraform for ${var.project_name}"

  tags = merge(
    local.common_tags,
    {
      Name = var.root_domain_name
    }
  )
}

# ============================================
# DNS Record for ALB
# ============================================

resource "aws_route53_record" "dev_server" {
  zone_id = var.create_route53_zone ? aws_route53_zone.main[0].zone_id : var.route53_zone_id
  name    = local.domain_name
  type    = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id                = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}
