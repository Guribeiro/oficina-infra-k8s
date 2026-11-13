# Rede do API Gateway compartilhada pelos ambientes: o VPC Link permite que as
# HTTP APIs de cada ambiente (stack environment) alcancem o NLB interno da aplicação.
# Security group das ENIs do VPC Link: só precisa sair para o NLB interno na VPC.
resource "aws_security_group" "vpc_link" {
  name        = "${var.name}-vpc-link"
  description = "ENIs do VPC Link do API Gateway"
  vpc_id      = var.vpc_id

  egress {
    description = "Trafego para o NLB interno da aplicacao"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = [var.vpc_cidr]
  }

  tags = var.tags
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = var.name
  subnet_ids         = var.subnet_ids
  security_group_ids = [aws_security_group.vpc_link.id]

  tags = var.tags
}
