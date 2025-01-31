provider "aws" {
  region = var.region
}

provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = [
      "eks", 
      "get-token", 
      "--cluster-name", module.eks.cluster_name,
      "--region", var.region  
    ]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)
    
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = [
        "eks",
        "get-token",
        "--cluster-name", module.eks.cluster_name,
        "--region", var.region
      ]
    }
  }
}

data "aws_eks_cluster" "cluster" {
  name = module.eks.cluster_name  
}

data "aws_eks_cluster_auth" "cluster" {
  name = data.aws_eks_cluster.cluster.name
}


# Filter out local zones, which are not currently supported 
# with managed node groups
data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  cluster_name = "webapp-eks-${random_string.suffix.result}"
}

resource "random_string" "suffix" {
  length  = 8
  special = false
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.8.1"

  name = "webapp-vpc"

  cidr = "10.0.0.0/16"

  azs  = slice(data.aws_availability_zones.available.names, 0, 3)

  private_subnets = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  public_subnets  = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  
  # Public and private subnets are tagged for use by ELB
  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "20.8.5"

  cluster_name    = local.cluster_name
  cluster_version = "1.32"

  # this allows public access to the cluster's API for testing purposes.
  # for prod envrionment, set this to false and use a secure private endpoint. Access should be managed through a bastion host or VPN for enhanced security
  cluster_endpoint_public_access           = true

  # grants the cluster creator admin permissions on the EKS cluster for testing purposes.
  # for prod environment, disable this setting and manage permissions using AWS IAM roles to adhere to the principle of least privilege.
  enable_cluster_creator_admin_permissions = true

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_group_defaults = {
    ami_type = "AL2_x86_64"

  }
  
  # adjust as per resource requirements
  eks_managed_node_groups = {
    one = {
      name = "node-group-1"

      instance_types = ["t3.micro"]

      min_size     = 1
      max_size     = 2
      desired_size = 1
    }

    two = {
      name = "node-group-2"

      instance_types = ["t3.micro"]

      min_size     = 1
      max_size     = 1
      desired_size = 1
    }
  }
}

# Configuration for NGINX Ingress Controller 
resource "kubernetes_namespace_v1" "ingress_nginx" {
  depends_on = [module.eks]
  metadata {
    name = "ingress-nginx"
  }
}

resource "helm_release" "nginx_ingress" {
  depends_on = [
  kubernetes_namespace_v1.ingress_nginx,
  module.eks
  ]
  name       = "ingress-nginx"
  namespace  = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.12.0"  

  values = [
    yamlencode({
      controller = {
        replicaCount = 1
        service = {
          type = "LoadBalancer"
          externalTrafficPolicy = "Local"
        }
        ingressClass = "nginx"
      }
    })
  ]
}

data "kubernetes_service_v1" "nginx_ingress" {
  depends_on = [helm_release.nginx_ingress]
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
}

