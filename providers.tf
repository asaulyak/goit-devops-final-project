# Kubernetes провайдер
# Використовує ТІЛЬКИ exec блок для автентифікації - не потребує data source
# Exec блок виконується тільки під час apply, коли кластер вже існує
# Це дозволяє виконувати terraform plan без помилок
provider "kubernetes" {
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks.cluster_name,
      "--region",
      var.aws_region
    ]
  }
}

# Helm провайдер
# Використовує ТІЛЬКИ exec блок для автентифікації
provider "helm" {
  kubernetes {
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args = [
        "eks",
        "get-token",
        "--cluster-name",
        module.eks.cluster_name,
        "--region",
        var.aws_region
      ]
    }
  }
}

# Data sources для отримання інформації про EKS кластер
# Використовуються для outputs
# 
# ВАЖЛИВО: Data sources визначені в main.tf, не дублюйте їх тут
# Під час першого plan/apply кластер не існує, тому data sources
# можуть показати помилку, але це нормально - просто виконайте terraform apply

