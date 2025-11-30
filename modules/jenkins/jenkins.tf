# Create namespace for Jenkins
resource "kubernetes_namespace" "jenkins" {
  metadata {
    name = var.namespace
    labels = {
      name = var.namespace
    }
  }
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = var.cluster_endpoint
  cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
  token                  = var.cluster_auth_token

  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      var.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

# Configure Helm provider
provider "helm" {
  kubernetes {
    host                   = var.cluster_endpoint
    cluster_ca_certificate = base64decode(var.cluster_ca_certificate)
    token                  = var.cluster_auth_token

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        var.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}

# Install Jenkins via Helm
resource "helm_release" "jenkins" {
  name       = "jenkins"
  repository = "https://charts.jenkins.io"
  chart      = "jenkins"
  version    = var.jenkins_chart_version
  namespace  = kubernetes_namespace.jenkins.metadata[0].name

  values = [
    file("${path.module}/${var.jenkins_values_file}")
  ]

  # Set Git repository environment variables if provided
  dynamic "set" {
    for_each = var.git_repository_url != "" ? [1] : []
    content {
      name  = "controller.env[2].value"
      value = var.git_repository_url
    }
  }

  dynamic "set" {
    for_each = var.git_repository_url != "" ? [1] : []
    content {
      name  = "controller.env[3].value"
      value = var.git_branch
    }
  }

  depends_on = [
    kubernetes_namespace.jenkins
  ]
}

