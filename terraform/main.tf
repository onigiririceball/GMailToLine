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

# Artifact Registry for Docker images
resource "google_artifact_registry_repository" "gmail_line_repo" {
  location      = "asia-northeast1"
  repository_id = "gmail-line-repo"
  description   = "Docker repository for Gmail to LINE notification app"
  format        = "DOCKER"
}

# Enable required Google Cloud APIs
resource "google_project_service" "cloud_run" {
  project            = "grounded-region-477206-b6"
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_scheduler" {
  project            = "grounded-region-477206-b6"
  service            = "cloudscheduler.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secret_manager" {
  project            = "grounded-region-477206-b6"
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifact_registry" {
  project            = "grounded-region-477206-b6"
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "iam" {
  project            = "grounded-region-477206-b6"
  service            = "iam.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "gmail" {
  project            = "grounded-region-477206-b6"
  service            = "gmail.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_resource_manager" {
  project            = "grounded-region-477206-b6"
  service            = "cloudresourcemanager.googleapis.com"
  disable_on_destroy = false
}

# Service Account for Cloud Run
resource "google_service_account" "cloud_run_sa" {
  account_id   = "cloud-run-sa"
  display_name = "Cloud Run Service Account"
  description  = "Service account for Gmail to LINE Cloud Run application"
  project      = "grounded-region-477206-b6"
}

# Service Account for GitHub Actions
resource "google_service_account" "github_actions_sa" {
  account_id   = "github-actions-sa"
  display_name = "GitHub Actions Service Account"
  description  = "Service account for GitHub Actions CI/CD pipeline"
  project      = "grounded-region-477206-b6"
}

# IAM permissions for Cloud Run Service Account
resource "google_project_iam_member" "cloud_run_secret_accessor" {
  project = "grounded-region-477206-b6"
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_project_iam_member" "cloud_run_log_writer" {
  project = "grounded-region-477206-b6"
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# IAM permissions for GitHub Actions Service Account
resource "google_project_iam_member" "github_actions_artifact_registry_writer" {
  project = "grounded-region-477206-b6"
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_run_admin" {
  project = "grounded-region-477206-b6"
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}

resource "google_project_iam_member" "github_actions_sa_user" {
  project = "grounded-region-477206-b6"
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.github_actions_sa.email}"
}
# Secret Manager Secrets
resource "google_secret_manager_secret" "gmail_credentials" {
  secret_id = "gmail-credentials"
  project   = "grounded-region-477206-b6"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secret_manager]
}

resource "google_secret_manager_secret" "line_channel_access_token" {
  secret_id = "line-channel-access-token"
  project   = "grounded-region-477206-b6"

  replication {
    auto {}
  }

  depends_on = [google_project_service.secret_manager]
}

# IAM binding for Cloud Run SA to access secrets
resource "google_secret_manager_secret_iam_member" "gmail_secret_access" {
  secret_id = google_secret_manager_secret.gmail_credentials.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

resource "google_secret_manager_secret_iam_member" "line_secret_access" {
  secret_id = google_secret_manager_secret.line_channel_access_token.id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Cloud Run Service
resource "google_cloud_run_service" "gmail_line_app" {
  name     = "gmail-line-app"
  location = "asia-northeast1"
  project  = "grounded-region-477206-b6"

  template {
    spec {
      service_account_name = google_service_account.cloud_run_sa.email

      containers {
        image = "asia-northeast1-docker.pkg.dev/grounded-region-477206-b6/gmail-line-repo/app:latest"

        resources {
          limits = {
            cpu    = "1"
            memory = "256Mi"
          }
        }

        env {
          name  = "PROJECT_ID"
          value = "grounded-region-477206-b6"
        }

        env {
          name  = "SECRET_NAME_GMAIL"
          value = "gmail-credentials"
        }

        env {
          name  = "SECRET_NAME_LINE"
          value = "line-channel-access-token"
        }
      }

      timeout_seconds = 60
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale" = "1"
        "autoscaling.knative.dev/minScale" = "0"
      }
    }
  }

  traffic {
    percent         = 100
    latest_revision = true
  }

  depends_on = [
    google_project_service.cloud_run,
    google_artifact_registry_repository.gmail_line_repo
  ]
}

# Allow Cloud Scheduler to invoke Cloud Run
resource "google_cloud_run_service_iam_member" "cloud_scheduler_invoker" {
  location = google_cloud_run_service.gmail_line_app.location
  project  = google_cloud_run_service.gmail_line_app.project
  service  = google_cloud_run_service.gmail_line_app.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_run_sa.email}"
}

# Cloud Scheduler Job
resource "google_cloud_scheduler_job" "gmail_line_scheduler" {
  name             = "gmail-line-scheduler"
  description      = "Trigger Gmail to LINE notification every 5 minutes"
  schedule         = "*/5 * * * *"
  time_zone        = "Asia/Tokyo"
  attempt_deadline = "320s"
  region           = "asia-northeast1"
  project          = "grounded-region-477206-b6"

  retry_config {
    retry_count = 1
  }

  http_target {
    http_method = "POST"
    uri         = google_cloud_run_service.gmail_line_app.status[0].url

    oidc_token {
      service_account_email = google_service_account.cloud_run_sa.email
    }
  }

  depends_on = [
    google_project_service.cloud_scheduler,
    google_cloud_run_service.gmail_line_app
  ]
}
