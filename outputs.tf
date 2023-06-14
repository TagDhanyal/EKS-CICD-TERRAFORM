output "eks_cluster_name" {
  value = aws_eks_cluster.eks_cluster.name
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.eks_cluster.endpoint
}
output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "aws_ecr_repository" {
  value = aws_ecr_repository.my_repository.arn
}
