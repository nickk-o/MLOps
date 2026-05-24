resource "kubernetes_namespace" "argocd" {
  metadata {
    name = var.argocd_namespace

    labels = {
      name      = var.argocd_namespace
      managedBy = "terraform"
    }
  }
}

resource "helm_release" "argocd" {
  name      = "argocd"
  namespace = kubernetes_namespace.argocd.metadata[0].name

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  values = [
    file("${path.module}/values/argocd-values.yaml")
  ]

  atomic          = false
  cleanup_on_fail = false
  timeout         = 1200

  depends_on = [
    kubernetes_namespace.argocd
  ]
}

resource "kubernetes_manifest" "namespaces_appset" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "namespaces-appset"
      namespace = var.argocd_namespace
    }
    spec = {
      generators = [
        {
          git = {
            repoURL  = var.app_repo_url
            revision = var.app_repo_branch
            directories = [
              {
                path = "namespaces/*"
              }
            ]
          }
        }
      ]
      template = {
        metadata = {
          name      = "ns-{{path.basename}}"
          namespace = var.argocd_namespace
        }
        spec = {
          project = "default"
          source = {
            repoURL        = var.app_repo_url
            targetRevision = var.app_repo_branch
            path           = "{{path}}"
            directory = {
              recurse = true
            }
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = "{{path.basename}}"
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = ["CreateNamespace=true"]
          }
          revisionHistoryLimit = 2
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}

resource "kubernetes_manifest" "root_application_appset" {
  manifest = {
    apiVersion = "argoproj.io/v1alpha1"
    kind       = "ApplicationSet"
    metadata = {
      name      = "root-application-appset"
      namespace = var.argocd_namespace
    }
    spec = {
      generators = [
        {
          list = {
            elements = [
              {
                name = "goit-argo-root"
                path = "."
              }
            ]
          }
        }
      ]
      template = {
        metadata = {
          name      = "{{name}}"
          namespace = var.argocd_namespace
        }
        spec = {
          project = "default"
          source = {
            repoURL        = var.app_repo_url
            targetRevision = var.app_repo_branch
            path           = "{{path}}"
          }
          destination = {
            server    = "https://kubernetes.default.svc"
            namespace = var.argocd_namespace
          }
          syncPolicy = {
            automated = {
              prune    = true
              selfHeal = true
            }
            syncOptions = ["CreateNamespace=true"]
          }
          revisionHistoryLimit = 2
        }
      }
    }
  }

  depends_on = [
    helm_release.argocd
  ]
}
