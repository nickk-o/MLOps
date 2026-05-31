locals {
  appset_placeholders = {
    path          = "{{path}}"
    path_basename = "{{path.basename}}"
    name          = "{{name}}"
  }

  bootstrap_extra_objects = [
    {
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
            name      = "ns-${local.appset_placeholders.path_basename}"
            namespace = var.argocd_namespace
          }
          spec = {
            project = "default"
            source = {
              repoURL        = var.app_repo_url
              targetRevision = var.app_repo_branch
              path           = local.appset_placeholders.path
              directory = {
                recurse = true
              }
            }
            destination = {
              server    = "https://kubernetes.default.svc"
              namespace = local.appset_placeholders.path_basename
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
    },
    {
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
            name      = local.appset_placeholders.name
            namespace = var.argocd_namespace
          }
          spec = {
            project = "default"
            source = {
              repoURL        = var.app_repo_url
              targetRevision = var.app_repo_branch
              path           = local.appset_placeholders.path
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
  ]
}

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

resource "kubectl_manifest" "namespaces_appset" {
  yaml_body = yamlencode(local.bootstrap_extra_objects[0])

  depends_on = [
    helm_release.argocd
  ]
}

resource "kubectl_manifest" "root_application_appset" {
  yaml_body = yamlencode(local.bootstrap_extra_objects[1])

  depends_on = [
    helm_release.argocd
  ]
}
