terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.27.0"
    }
  }
}

provider "google" {
# Credentials only needs to be set if you do not have the GOOGLE_APPLICATION_CREDENTIALS set
  credentials = file("/Users/liangyanlin/Desktop/project/keys/my-creds.json")
  project = "sf-registered-business"
  region  = "us-west2"
}



resource "google_storage_bucket" "data-lake-bucket" {
  name          = "sf-registered-business"
  location      = "US"

  # Optional, but recommended settings:
  storage_class = "STANDARD"
  uniform_bucket_level_access = true

  versioning {
    enabled     = true
  }

  lifecycle_rule {
    action {
      type = "Delete"
    }
    condition {
      age = 30  // days
    }
  }

  force_destroy = true
}


resource "google_bigquery_dataset" "sf-business-dataset" {
  dataset_id = "sf_registered_business"
  project    = "sf-registered-business"
  location   = "US"
}
