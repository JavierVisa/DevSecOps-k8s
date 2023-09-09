terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "4.81.0"
    }
  }
}

provider "google" {
  project = "jvc-project-01"
  region  = "europe-west1"
  zone    = "europe-west1-b"
}

locals {
  instance_name = "devsecops-k8s"
}

# SERVICE ACCOUNT
resource "google_service_account" "sa" {
  account_id   = "${local.instance_name}-sa"
  display_name = "A service account for the instance ${local.instance_name}"
}

resource "google_project_iam_member" "compute" {
  project = "jvc-project-01"
  role    = "roles/editor"
  member  = "serviceAccount:${google_service_account.sa.email}"
}

# INSTANCE
data "google_compute_image" "ubuntu_18" {
  family  = "ubuntu-pro-1804-lts"
  project = "ubuntu-os-pro-cloud"
}

resource "google_compute_instance" "default" {
  name         = local.instance_name
  machine_type = "n2-standard-4"
  zone         = "europe-west1-b"

  boot_disk {
    initialize_params {
      size  = 512
      type  = "pd-standard"
      image = data.google_compute_image.ubuntu_18.self_link
    }
  }

  tags = ["${local.instance_name}-access"]

  metadata = {
    ssh-keys = "javier:${file("/home/javier/.ssh/id_rsa.pub")}"
  }

  network_interface {
    network    = "projects/jvc-project-01/global/networks/pocs-vpc"
    subnetwork = "projects/jvc-project-01/regions/europe-west1/subnetworks/subnet-a"

    access_config {
      // Ephemeral public IP if its empty
    }
  }
  service_account {
    email  = google_service_account.sa.email
    scopes = ["cloud-platform"]
  }
}

resource "google_compute_firewall" "instance-access" {
  name    = "${local.instance_name}-access"
  network = "projects/jvc-project-01/global/networks/pocs-vpc"

  allow {
    protocol = "tcp"
    ports    = ["22"]   # Add new ports if required
  }

  source_ranges = ["5.59.63.65"]    # Home IP
  target_tags   = ["${local.instance_name}-access"]
}