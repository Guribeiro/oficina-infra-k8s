terraform {
  # Informados no init (scripts/tf.sh):
  #   -backend-config="bucket=$TF_STATE_BUCKET"
  #   -backend-config="key=oficina-infra-k8s/platform/terraform.tfstate"
  backend "s3" {
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
