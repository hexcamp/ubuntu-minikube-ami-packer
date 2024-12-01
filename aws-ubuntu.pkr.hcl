packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.8"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

source "amazon-ebs" "ubuntu" {
  ami_name      = "hexcamp-ubuntu-minikube-2"
  instance_type = "t2.micro"
  region        = "us-west-1"
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    most_recent = true
    owners      = ["099720109477"]
  }
  ssh_username = "ubuntu"
}

build {
  name = "hexcamp-ubuntu-minikube"
  sources = [
    "source.amazon-ebs.ubuntu"
  ]
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "apt-get remove unattended-upgrades -y",
      "apt-get update",
      "apt-get upgrade -y",
      "apt-get install -y curl wget apt-transport-https ca-certificates",
      "systemctl stop apparmor.service",
      "systemctl disable apparmor.service",
      ## https://www.server-world.info/en/note?os=Ubuntu_24.04&p=apparmor&f=1
      "perl -pi -e 's/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"apparmor=0\"/' /etc/default/grub",
      "update-grub",
      "apt-get install containerd -y",
    ]
  }

  provisioner "file" {
    destination = "/home/ubuntu/containerd.conf"
    content     = <<EOT
overlay
br_netfilter
EOT
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "mv /home/ubuntu/containerd.conf /etc/modules-load.d/containerd.conf",
      "chown root:root /etc/modules-load.d/containerd.conf",
      "modprobe overlay",
      "modprobe br_netfilter",
    ]
  }

  # Setup required sysctl params, these persist across reboots.
  provisioner "file" {
    destination = "/home/ubuntu/99-kubernetes-cri.conf"
    content     = <<EOT
net.bridge.bridge-nf-call-iptables  = 1
net.ipv4.ip_forward                 = 1
net.bridge.bridge-nf-call-ip6tables = 1
EOT
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "mv /home/ubuntu/99-kubernetes-cri.conf /etc/sysctl.d/99-kubernetes-cri.conf",
      "chown root:root /etc/sysctl.d/99-kubernetes-cri.conf",
      "sysctl --system",
    ]
  }

  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "mkdir -p /etc/containerd",
      "containerd config default > /etc/containerd/config.toml",
      "sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml",
      "systemctl restart containerd",
      "systemctl enable containerd",
    ]
  }

  # Install Kubernetes components
  # https://kubernetes.io/blog/2023/08/15/pkgs-k8s-io-introduction/
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /' | tee /etc/apt/sources.list.d/kubernetes.list",
      "curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg",
      "apt-get update",
      "apt-get install kubectl kubelet kubeadm kubernetes-cni -y",
      "systemctl enable kubelet",
      "systemctl start kubelet",
    ]
  }

  # Free up port 53
  # https://unix.stackexchange.com/questions/676942/free-up-port-53-on-ubuntu-so-custom-dns-server-can-use-it
  # https://www.linuxuprising.com/2020/07/ubuntu-how-to-free-up-port-53-used-by.html
  provisioner "shell" {
    execute_command = "sudo sh -c '{{ .Vars }} {{ .Path }}'"
    inline = [
      "perl -pi -e 's/^#DNS=.*/DNS=8.8.8.8/' /etc/systemd/resolved.conf",
      "perl -pi -e 's/^#DNSStubListener=.*/DNSStubListener=no/' /etc/systemd/resolved.conf",
      "ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf",
    ]
  }
}

