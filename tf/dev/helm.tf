resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  version          = "v1.14.5"
  timeout          = 600

  values = [
    yamlencode({
      installCRDs = true
    })
  ]
}

data "template_file" "aws_load_balancer_controller_values" {
  template = file("${path.module}/aws-load-balancer-controller-values.yaml.tpl")

  vars = {
    cluster_name = module.eks.cluster_name
    role_arn     = aws_iam_role.aws_load_balancer_controller.arn
  }
}

resource "helm_release" "aws_load_balancer_controller" {
  name       = "aws-load-balancer-controller"
  repository = "https://aws.github.io/eks-charts"
  chart      = "aws-load-balancer-controller"
  namespace  = "kube-system"
  version    = "1.7.1"

  values = [
    data.template_file.aws_load_balancer_controller_values.rendered
  ]

  depends_on = [
    helm_release.cert_manager
  ]
}