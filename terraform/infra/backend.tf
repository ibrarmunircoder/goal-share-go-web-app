terraform {
  backend "s3" {
    bucket       = "terraform-go-goal-share-service"
    key          = "terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}