terraform {
  backend "s3" {
    bucket       = "384081048358-tfstate-2"
    key          = "terraform.tfstate"
    region       = "ap-northeast-1"
    encrypt      = true
    use_lockfile = true
  }
}