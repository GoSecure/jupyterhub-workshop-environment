# Keypair
resource "tls_private_key" "do_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4089
}

resource "digitalocean_ssh_key" "do_ssh_key" {
  name       = "${var.workshop_name}-ssh-key"
  public_key = tls_private_key.do_ssh_key.public_key_openssh
}

# Server (Droplet)
resource "digitalocean_droplet" "jupyterhub-server" {
  image    = "ubuntu-22-04-x64"
  name     = var.workshop_name
  region   = var.instance_region
  vpc_uuid = digitalocean_vpc.vpc.id

  size        = var.instance_size
  resize_disk = false
  tags        = local.tags
  ssh_keys    = [digitalocean_ssh_key.do_ssh_key.fingerprint]
}

resource "null_resource" "provision" {

  connection {
    host        = digitalocean_droplet.jupyterhub-server.ipv4_address
    user        = "root"
    type        = "ssh"
    private_key = tls_private_key.do_ssh_key.private_key_openssh
    timeout     = "2m"
  }

  # Install TLJH
  provisioner "remote-exec" {
    inline = [
      "until [ -f /var/lib/cloud/instance/boot-finished ]; do sleep 1; done",
      "NEEDRESTART_MODE=a apt-get -y update",
      "NEEDRESTART_MODE=a apt-get install -y python3 python3-dev git curl",
      <<-EOF
      curl -L https://tljh.jupyter.org/bootstrap.py \
       | sudo python3 - --admin admin:${random_password.admin_password.result} \
       --plugin git+https://github.com/kafonek/tljh-shared-directory \
       --user-requirements-txt-url ${var.workshop_requirements_url}
      EOF
      ,
      # linking to /srv/workshop from new users' home
      "mkdir -p /srv/workshop/",
      "ln -s /srv/workshop/ /etc/skel/workshop-readonly",
      # preparing assignments directory
      "mkdir -p /etc/skel/your-personal-lab/"
    ]
  }

  # Copy workshop data files
  provisioner "file" {
    source      = "workshop-data/"
    destination = "/srv/workshop/"
  }

  # Copy exercises into user skel
  provisioner "file" {
    source      = "workshop-data/assignments/"
    destination = "/etc/skel/your-personal-lab/"
  }

  # Copy tljh yaml config
  provisioner "file" {
    content = templatefile("templates/config.yaml", {
      github_client_id      = var.github_client_id
      github_client_secret  = var.github_client_secret
      workshop_domain       = var.workshop_domain
      workshop_contact      = var.workshop_contact
      jupyterhub_admin      = var.jupyterhub_admin
    })
    destination = "/opt/tljh/config/config.yaml"
  }

  # Finalize
  provisioner "remote-exec" {
    inline = [
      # Access control: no access to solutions
      "chmod go-rwx /srv/workshop/solutions",
      # tljh proxy reload for HTTPS to work
      "tljh-config reload proxy",
      # tljh reload
      "tljh-config reload"
    ]
  }
}

# Assigns the resource to the workshops project
resource "digitalocean_project_resources" "Workshops_resources" {
  project   = data.digitalocean_project.workshops.id
  resources = [digitalocean_droplet.jupyterhub-server.urn]
}

# Assigns random VPC to avoid default VPC exposure to other infrastructure
resource "random_pet" "vpc_name" {}
resource "digitalocean_vpc" "vpc" {
  name   = "workshop-vpc-${random_pet.vpc_name.id}"
  region = var.instance_region
}

# Throwaway password for the admin user (overridden by jupyterhub_admin)
resource "random_string" "admin_password" {
  length  = 16
  special = false
}