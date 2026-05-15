data "terraform_remote_state" "vpc" {
  count = var.use_remote_state ? 1 : 0

  backend = "s3"

  config = {
    bucket = var.remote_state_bucket
    key    = var.remote_state_key
    region = var.remote_state_region
  }
}
