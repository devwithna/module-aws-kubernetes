provider "aws" {
  region = var.aws_region
}

locals {
  cluster_name = "${var.cluster_name}-${var.env_name}"
}

# EKS Cluster Resources
#  * IAM Role to allow EKS service to manage other AWS services
#  * EC2 Security Group to allow networking traffic with EKS cluster
#  * EKS Cluster
#

resource "aws_iam_role" "grn-at-cluster" {
  name = local.cluster_name

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "grn-at-cluster-AmazonEKSClusterPolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.grn-at-cluster.name
}

resource "aws_security_group" "grn-at-cluster" {
  name        = local.cluster_name
  description = "Cluster communication with worker nodes"
  vpc_id      = var.vpc_id

  ingress {
    description = "Inbound traffic from within the security group"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }

  tags = {
    Name = "grn-at-client-managing"
  }
}

resource "aws_eks_cluster" "grn-at-client-managing" {
  name     = local.cluster_name
  role_arn = aws_iam_role.grn-at-cluster.arn

  vpc_config {
    security_group_ids = [aws_security_group.grn-at-cluster.id]
    subnet_ids         = var.cluster_subnet_ids
  }

  depends_on = [
    aws_iam_role_policy_attachment.grn-at-cluster-AmazonEKSClusterPolicy
  ]
}

resource "aws_iam_role" "grn-at-node" {
  name = "${local.cluster_name}.node"

  assume_role_policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
POLICY
}

resource "aws_iam_role_policy_attachment" "grn-at-node-AmazonEKSWorkerNodePolicy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.grn-at-node.name
}

resource "aws_iam_role_policy_attachment" "grn-at-node-AmazonEKS_CNI_Policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.grn-at-node.name
}

resource "aws_iam_role_policy_attachment" "grn-at-node-AmazonEC2ContainerRegistryReadOnly" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.grn-at-node.name
}

resource "aws_eks_node_group" "grn-at-node-group" {
  cluster_name    = aws_eks_cluster.grn-at-client-managing.name
  node_group_name = "grnATService"
  node_role_arn   = aws_iam_role.grn-at-node.arn
  subnet_ids      = var.nodegroup_subnet_ids

  scaling_config {
    desired_size = var.nodegroup_desired_size
    max_size     = var.nodegroup_max_size
    min_size     = var.nodegroup_min_size
  }

  disk_size      = var.nodegroup_disk_size
  instance_types = var.nodegroup_instance_types

  depends_on = [
    aws_iam_role_policy_attachment.grn-at-node-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.grn-at-node-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.grn-at-node-AmazonEC2ContainerRegistryReadOnly,
  ]
}

# Create a kubeconfig file based on the cluster that has been created
resource "local_file" "kubeconfig" {
  content  = <<KUBECONFIG
apiVersion: v1
clusters:
- cluster:
    certificate-authority-data: ${aws_eks_cluster.grn-at-client-managing.certificate_authority.0.data}
    server: ${aws_eks_cluster.grn-at-client-managing.endpoint}
  name: ${aws_eks_cluster.grn-at-client-managing.arn}
contexts:
- context:
    cluster: ${aws_eks_cluster.grn-at-client-managing.arn}
    user: ${aws_eks_cluster.grn-at-client-managing.arn}
  name: ${aws_eks_cluster.grn-at-client-managing.arn}
current-context: ${aws_eks_cluster.grn-at-client-managing.arn}
kind: Config
preferences: {}
users:
- name: ${aws_eks_cluster.grn-at-client-managing.arn}
  user:
    exec:
      apiVersion: client.authentication.k8s.io/v1alpha1
      command: aws-iam-authenticator
      args:
        - "token"
        - "-i"
        - "${aws_eks_cluster.grn-at-client-managing.name}"
    KUBECONFIG
  filename = "kubeconfig"
}
/*
#  Use data to ensure that the cluster is up before we start using it
data "aws_eks_cluster" "msur" {
  name = aws_eks_cluster.grn-at-client-managing.id
}
# Use kubernetes provider to work with the kubernetes cluster API
provider "kubernetes" {
  load_config_file       = false
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.msur.certificate_authority.0.data)
  host                   = data.aws_eks_cluster.msur.endpoint
  exec {
    api_version = "client.authentication.k8s.io/v1alpha1"
    command     = "aws-iam-authenticator"
    args        = ["token", "-i", "${data.aws_eks_cluster.msur.name}"]
  }
}
# Create a namespace for microservice pods 
resource "kubernetes_namespace" "ms-namespace" {
  metadata {
    name = var.ms_namespace
  }
}
*/