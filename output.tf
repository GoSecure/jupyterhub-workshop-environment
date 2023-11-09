output "instance_public_key" {
  value = tls_private_key.do_ssh_key.public_key_openssh
}

output "instance_private_key" {
  value     = tls_private_key.do_ssh_key.private_key_pem
  sensitive = true
}

output "jupyterhub_public_ip" {
  value = digitalocean_droplet.jupyterhub-server.ipv4_address
}

output "workshop_domain" {
  value = var.workshop_domain
}

output "next_steps" {
  value = "Please update your DNS to point the public IP to the workshop_domain as quickly as you can for Lets Encrypt to work (automatically done by the trafaek proxy)"
}