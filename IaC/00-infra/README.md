## IaC AWS-EKS Terraform module for AWS VPC and EKS custom modules 

The module has two different flavor "dev" and "prod"

#### Common stages for installation:
- Creates a VPC with private and public subnets, then an Internet Gateway to assign to public subnets
- EKS Controllers and the node group is getting installed on private subnets

#### dev:
- Worker node instance types for "dev" are set via the `image_types` map in tfvars.
- What endpoints are going to be placed to VPC is defined at tfvars with "endpoints_interface". S3 creation is hardcoded (it is always required and its type Gateway). Node Group servers reaching to services via gateway and interface endpoints defined at tfvars. "AmazonEC2ContainerRegistryReadOnly" allow to reading from any ECR registry. Every image related to workflow should be in ECR. There is no any other registry or artifact repo access. 

#### prod:
- Worker node instance types for "prod" are set via the `image_types` map in tfvars.
- A Regional Nat Gateway is being created at VPC level and associated to private subnets. Node Group servers getting one way access to world.

#### Prerequisites
- Terraform CLI installed
- AWS credentials configured (e.g. via `aws configure` or environment variables) with permissions to manage VPC/EKS resources

#### Usage
```bash
terraform init
terraform plan  -var-file="terraform.tfvars"
terraform apply -var-file="terraform.tfvars"
```
Update [terraform.tfvars](terraform.tfvars) for your environment before applying (see comment at the top of [main.tf](main.tf)).

#### Inputs
| Name | Description | Type |
|---|---|---|
| `region` | AWS region | `string` |
| `vpc_cidr` | CIDR block for the VPC | `string` |
| `project_name` | Name/prefix used for resources | `string` |
| `keypair_name` | EC2 keypair name | `string` |
| `environment` | `dev` or `prod` (default `dev`) | `string` |
| `endpoints_interface` | VPC endpoint interface service names (e.g. `ecr.api`, `ecr.dkr`, `ec2`) | `set(string)` |
| `image_types` | Worker node instance types per environment | `map(list(string))` |
| `subnets` | Subnet definitions (cidr, az, is_public) | `map(object)` |

#### Outputs
| Name | Description |
|---|---|
| `public_ip` | Public IP address of the Terraform runner |
| `Environment` | The environment (`dev`/`prod`) that was applied |


