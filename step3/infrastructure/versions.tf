terraform {
  required_version = ">= 0.13"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0.2"
    }

    http = {
      source  = "hashicorp/http"
      version = "~> 2.1.0"
    }

    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0.3"
    }

    null = {
      source  = "hashicorp/null"
      version = "~> 3.1.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.1.0"
    }
  }
}