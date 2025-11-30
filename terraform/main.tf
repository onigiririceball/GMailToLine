terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.8.0"
    }
  }
}

provider "google" {
  project = "grounded-region-477206-b6"
  region  = "asia-northeast1"
  zone    = "asia-northeast1"
}

resource "google_compute_network" "vpc_network" {
  name = "terraform-network"
}

