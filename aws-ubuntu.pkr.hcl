packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "hexcamp-ubuntu-minikube-arm64"
  instance_type = "t4g.micro"
  region        = "us-west-1"
  source_ami_filter {
    filters = {
      #name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-arm64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

build {
  name = "hexcamp-ubuntu-minikube-arm64"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
}

