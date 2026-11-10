# GitHub CI infrastructure (Terraform)

Creates: required APIs, Workload Identity Pool + GitHub OIDC provider, CI service account,
Artifact Registry (Docker) repository with cleanup policies, and least-privilege IAM.

    cp terraform.tfvars.example terraform.tfvars   # edit values
    terraform init
    terraform plan
    terraform apply
    terraform output github_actions_variables      # paste into GitHub > Settings > Variables

Apply with an identity that can create IAM resources (e.g. project Owner or equivalent).
