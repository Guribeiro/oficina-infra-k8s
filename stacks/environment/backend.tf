terraform {
  # Informados no init:
  #   -backend-config="bucket=$TF_STATE_BUCKET"
  #   -backend-config="key=oficina-infra-k8s/environment/<hml|prd>/terraform.tfstate"
  backend "s3" {
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
