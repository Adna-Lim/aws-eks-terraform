# Provision an EKS Cluster using Terraform

This repository contains Terraform configuration files to provision an EKS cluster on AWS. The setup includes deploying an NGINX Ingress Controller to manage external access to services running in the cluster.

### Cost Warning ⚠️
AWS EKS clusters cost $0.10 per hour, which may lead to charges while running this setup. To avoid unnecessary costs, ensure you delete the infrastructure after use.
```
terraform destroy
```
For more details: https://aws.amazon.com/eks/pricing/

## Overall Architecture

<p align="center">
<img src="images/eks_cluster.png" alt="image" style="width:500px;"/>
</p>

- **EKS Cluster**: A scalable EKS cluster with managed node groups
- **NGINX Ingress Controller**: For routing external traffic to services within the cluster
- **VPC Setup**: Configured with private and public subnets to support cluster networking

## Prerequisites

1. AWS CLI configured with appropriate credentials
2. kubectl installed
3. Terraform installed 

## Infrastructure Deployment

Deploy the infrastructure using the following commands:

```
# Initialize Terraform working directory
terraform init
# Preview the changes to be applied
terraform plan
# Apply the changes to create the infrastructure
terraform apply
```

Once the Terraform deployment is complete, the following information will be output:
    * Cluster Endpoint
    * Cluster Security Group ID
    * AWS Region
    * Cluster Name
    * NGINX Ingress Load Balancer Hostname

After deployment, retrieve the Kubernetes config with the following command:
```
aws eks --region <your-region> update-kubeconfig --name <eks-cluster-name>
```

After retrieving the kubeconfig, you can now interact with the EKS cluster using kubectl. 