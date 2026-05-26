terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.7.1"
    }
  }
}

provider "libvirt" {
  uri = "qemu:///system"
}

resource "libvirt_volume" "ubuntu_image" {
  name   = "ubuntu-image"
  pool   = "default"
  source = "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  format = "qcow2"
}

resource "libvirt_volume" "worker_disk" {
  name           = "worker.qcow2"
  base_volume_id = libvirt_volume.ubuntu_image.id
  pool           = "default"
  size           = 10737418240 # 10GB
}

resource "libvirt_volume" "db_disk" {
  name           = "db.qcow2"
  base_volume_id = libvirt_volume.ubuntu_image.id
  pool           = "default"
  size           = 10737418240 # 10GB
}

resource "libvirt_cloudinit_disk" "commoninit" {
  name      = "commoninit.iso"
  pool      = "default"
  user_data = templatefile("${path.module}/cloud_init.cfg", {
    ssh_key = file("/home/edward/.ssh/id_rsa.pub")
  })
}

# Створення VM1 (Worker)
resource "libvirt_domain" "worker" {
  name   = "worker"
  memory = "1024"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.worker_disk.id
  }

  # Цей блок примусово змінює тип гіпервізора на qemu
  xml {
    xslt = <<EOF
<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="node()|@*">
    <xsl:copy><xsl:apply-templates select="node()|@*"/></xsl:copy>
  </xsl:template>
  <xsl:template match="domain/@type">
    <xsl:attribute name="type">qemu</xsl:attribute>
  </xsl:template>
</xsl:stylesheet>
EOF
  }
}

# Створення VM2 (DB)
resource "libvirt_domain" "db" {
  name   = "db"
  memory = "1024"
  vcpu   = 1

  cloudinit = libvirt_cloudinit_disk.commoninit.id

  network_interface {
    network_name   = "default"
    wait_for_lease = true
  }

  disk {
    volume_id = libvirt_volume.db_disk.id
  }

  # Цей блок примусово змінює тип гіпервізора на qemu
  xml {
    xslt = <<EOF
<?xml version="1.0" ?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:template match="node()|@*">
    <xsl:copy><xsl:apply-templates select="node()|@*"/></xsl:copy>
  </xsl:template>
  <xsl:template match="domain/@type">
    <xsl:attribute name="type">qemu</xsl:attribute>
  </xsl:template>
</xsl:stylesheet>
EOF
  }
}

output "worker_ip" {
  value = libvirt_domain.worker.network_interface[0].addresses[0]
}

output "db_ip" {
  value = libvirt_domain.db.network_interface[0].addresses[0]
}
