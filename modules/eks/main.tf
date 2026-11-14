# AWS Learner Lab não permite criar roles IAM: o cluster e os nodes usam as roles
# pré-provisionadas pelo laboratório. Dependendo da conta, o nome vem exato
# (LabEksClusterRole) ou com prefixo/sufixo da stack CloudFormation do lab
# (c2290...-LabEksClusterRole-nNA0ybf1ERea); a busca aceita os dois formatos.
data "aws_iam_roles" "cluster" {
  name_regex = "(^|-)${var.cluster_role_name}(-[A-Za-z0-9]+)?$"
}

data "aws_iam_roles" "node" {
  name_regex = "(^|-)${var.node_role_name}(-[A-Za-z0-9]+)?$"
}

data "aws_iam_role" "cluster" {
  name = one(data.aws_iam_roles.cluster.names)

  lifecycle {
    precondition {
      condition     = length(data.aws_iam_roles.cluster.names) == 1
      error_message = "Esperada exatamente uma role contendo ${var.cluster_role_name}; encontradas: ${jsonencode(data.aws_iam_roles.cluster.names)}."
    }
  }
}

data "aws_iam_role" "node" {
  name = one(data.aws_iam_roles.node.names)

  lifecycle {
    precondition {
      condition     = length(data.aws_iam_roles.node.names) == 1
      error_message = "Esperada exatamente uma role contendo ${var.node_role_name}; encontradas: ${jsonencode(data.aws_iam_roles.node.names)}."
    }
  }
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  version  = var.kubernetes_version
  role_arn = data.aws_iam_role.cluster.arn

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  # Quem cria o cluster (sessão do Learner Lab, a mesma usada no CI) vira administrador.
  access_config {
    authentication_mode                         = "API_AND_CONFIG_MAP"
    bootstrap_cluster_creator_admin_permissions = true
  }

  enabled_cluster_log_types = ["api", "audit"]

  tags = var.tags
}

resource "aws_eks_node_group" "default" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-workers"
  node_role_arn   = data.aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.node_instance_types
  capacity_type   = "ON_DEMAND"
  disk_size       = 20

  scaling_config {
    min_size     = var.node_min_size
    desired_size = var.node_desired_size
    max_size     = var.node_max_size
  }

  update_config {
    max_unavailable = 1
  }

  tags = var.tags

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}

resource "aws_eks_addon" "this" {
  for_each = toset(["vpc-cni", "kube-proxy", "coredns"])

  cluster_name                = aws_eks_cluster.this.name
  addon_name                  = each.value
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  tags = var.tags

  depends_on = [aws_eks_node_group.default]
}
