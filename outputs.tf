output "eks_cluster_id" {
  value = aws_eks_cluster.grn-at-client-managing.id
}

output "eks_cluster_name" {
  value = aws_eks_cluster.grn-at-client-managing.name
}

output "eks_cluster_certificate_data" {
  value = aws_eks_cluster.grn-at-client-managing.certificate_authority.0.data
}

output "eks_cluster_endpoint" {
  value = aws_eks_cluster.grn-at-client-managing.endpoint
}

output "eks_cluster_nodegroup_id" {
  value = aws_eks_node_group.grn-at-node-group.id
}

output "eks_cluster_security_group_id" {
  value = aws_security_group.grn-at-cluster.id
}