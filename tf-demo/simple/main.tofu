terraform {
  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.49"
    }
  }
}

provider "hcloud" {}

locals {
  environment = "staging"

  # The hostname may have non-ASCII characters; DNS needs it in its punycode form.
  hostname = "你好.example.com"

  labels = {
    environment = local.environment
    managed-by  = "opentofu"
  }
}

# Things that already exist in Hetzner Cloud.

data "hcloud_location" "primary" {
  name = "nbg1"
}

data "hcloud_server_type" "small" {
  name = "cx22"
}

data "hcloud_image" "ubuntu" {
  name              = "ubuntu-24.04"
  with_architecture = data.hcloud_server_type.small.architecture
}

# Access and networking.

resource "hcloud_ssh_key" "deploy" {
  name       = "deploy-${local.environment}"
  public_key = file("~/.ssh/id_ed25519.pub")
  labels     = local.labels
}

resource "hcloud_network" "private" {
  name     = "private-${local.environment}"
  ip_range = "10.0.0.0/16"
  labels   = local.labels
}

resource "hcloud_network_subnet" "app" {
  network_id   = hcloud_network.private.id
  type         = "cloud"
  network_zone = data.hcloud_location.primary.network_zone
  ip_range     = "10.0.1.0/24"
}

resource "hcloud_firewall" "web" {
  name   = "web-${local.environment}"
  labels = local.labels

  rule {
    description = "SSH"
    direction   = "in"
    protocol    = "tcp"
    port        = "22"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "HTTP"
    direction   = "in"
    protocol    = "tcp"
    port        = "80"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }

  rule {
    description = "HTTPS"
    direction   = "in"
    protocol    = "tcp"
    port        = "443"
    source_ips  = ["0.0.0.0/0", "::/0"]
  }
}

# The application server, and its data volume.

resource "hcloud_server" "app" {
  name         = "app-${local.environment}"
  server_type  = data.hcloud_server_type.small.name
  image        = data.hcloud_image.ubuntu.name
  location     = data.hcloud_location.primary.name
  ssh_keys     = [hcloud_ssh_key.deploy.id]
  firewall_ids = [hcloud_firewall.web.id]
  labels       = local.labels

  public_net {
    ipv4_enabled = true
    ipv6_enabled = true
  }

  network {
    network_id = hcloud_network.private.id
    ip         = "10.0.1.10"
  }

  depends_on = [hcloud_network_subnet.app]
}

resource "hcloud_volume" "data" {
  name     = "data-${local.environment}"
  size     = 20
  format   = "ext4"
  location = data.hcloud_location.primary.name
  labels   = local.labels
}

resource "hcloud_volume_attachment" "data" {
  volume_id = hcloud_volume.data.id
  server_id = hcloud_server.app.id
  automount = true
}

resource "hcloud_rdns" "app" {
  server_id  = hcloud_server.app.id
  ip_address = hcloud_server.app.ipv4_address
  dns_ptr    = provider::hcloud::idna(local.hostname)
}

# Read the server back, once the volume is attached.

data "hcloud_server" "app" {
  id         = hcloud_server.app.id
  depends_on = [hcloud_volume_attachment.data]
}

output "app_public_ip" {
  value = data.hcloud_server.app.ipv4_address
}

output "app_private_ip" {
  value = hcloud_server.app.network[*].ip
}

output "app_hostname" {
  value = hcloud_rdns.app.dns_ptr
}

output "app_location" {
  value = "${data.hcloud_location.primary.city} (${data.hcloud_location.primary.name})"
}
