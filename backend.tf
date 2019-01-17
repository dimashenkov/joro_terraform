terraform {
    backend "s3" {
        bucket = "compbio-terraform-s3-stage"
        key    = "./terraform-stage.tfstate"
        region = "us-west-1"
    }
}
