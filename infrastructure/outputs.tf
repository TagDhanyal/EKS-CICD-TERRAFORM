output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}

output "eks_node_group_id" {
  value = aws_eks_node_group.eks_node_group.id
}

output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "aws_ecr_repository" {
  value = aws_ecr_repository.my_repository.arn
}
