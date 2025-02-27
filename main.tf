terraform {
required_providers {
    equinix = {
      source = "equinix/equinix"
    }
  }
}


provider "equinix" {
  auth_token = var.metal_auth_token
}

resource "tls_private_key" "ssh_key_pair" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "equinix_metal_ssh_key" "ssh_pub_key" {
  name       = "eqx_pub"
  public_key = chomp(tls_private_key.ssh_key_pair.public_key_openssh)
}

resource "local_file" "cluster_private_key_pem" {
  content         = chomp(tls_private_key.ssh_key_pair.private_key_pem)
  filename        = pathexpand(format("~/.ssh/%s", "eqx_priv"))
  file_permission = "0600"
}


resource "equinix_metal_device" "baremachines" {
  depends_on = [
    equinix_metal_ssh_key.ssh_pub_key
  ]
  count            = var.nodes_count
  hostname         = format("%s-%02d", "soln-pds-demo", count.index + 1)
  plan             = var.node_plan
  metro            = var.metro
  operating_system = var.operating_system
  billing_cycle    = var.billing_cycle
  project_id       = var.metal_project_id
  lifecycle {
    create_before_destroy = true
  }
}

locals {
  mydata = zipmap(equinix_metal_device.baremachines.*.hostname, equinix_metal_device.baremachines.*.access_public_ipv4)
  ndata = join(" ", [for key, value in local.mydata : "${key},${value}"])
}

data "template_file" "config-vars" {
  template = file("${path.module}/templates/cluster-config-vars.template")
  vars = {
    XX_HOST_IPS_XX = local.ndata
    XX_SSH_USER_XX = var.ssh_user
    XX_KSVER_XX = var.kubespray_version
    XX_K8SVER_XX = var.k8s_version
    XX_PXOP_XX = var.px_operator_version
    XX_PXSTG_XX = var.px_stg_version
    XX_CPH_XX = var.cp_node_count
    XX_CLUSTER_NAME_XX = var.cluster_name
    XX_PX_SECURITY_XX = var.px_security
    }
}

resource "local_file" "cluster-config-vars" {
  content  = "${data.template_file.config-vars.rendered}"
  filename = "${path.root}/cluster-config-vars"
}

resource "null_resource" "local_setup" {
  depends_on = [
    equinix_metal_device.baremachines
  ]
  provisioner "local-exec" {
    command = <<-EOT
      cp -p templates/find-kvdb-dev.sh templates/add-node.sh templates/remove-node.sh templates/kvdb-dev.yaml templates/nvars .
      cat templates/vars.template > vars
      cp -p cluster-config-vars ncluster-config-vars
      chmod a+x vars
      EOT
      interpreter = ["/bin/bash", "-c"]
      working_dir = path.module
  }
}

module "k8s_setup" {
  depends_on = [null_resource.local_setup, local_file.cluster-config-vars]
  source = "./modules/k8s_setup"
}

module "portworx" {
  depends_on = [ module.k8s_setup ]
  source = "./modules/portworx"
}

resource "time_sleep" "wait_5_minutes" {
  depends_on = [ module.portworx ]
  create_duration = "5m"
}

module "portworx_data_services" {
  depends_on = [ module.portworx, time_sleep.wait_5_minutes, null_resource.pds_remove  ]
  source = "./modules/portworx_data_services"
  tenant_id = var.tenant_id
  px_operator_version = var.px_operator_version
  pds_token = var.pds_token
  pds_name = var.pds_name
  #helm_version = var.helm_version
  account_id = var.account_id
}

data "external" "get_cluster_id" {
  depends_on = [ module.k8s_setup ]
  program = ["sh", "-c", "/usr/local/bin/kubectl --kubeconfig ./modules/k8s_setup/kube-config-file get namespace kube-system -o jsonpath='{\"{\"}\"cluster-id\": \"{.metadata.uid}\"}'"]
}

locals {
#old_count = var.nodes_count
#scale_count = "${var.nodes_count} - ${local.old_count}"
extd = data.external.get_cluster_id.result
}

resource "null_resource" "pds_remove" {
  triggers = {
    token_id = var.pds_token
    tenant_id = var.tenant_id
  }

  provisioner "local-exec" {
    when    = destroy
    on_failure = continue
    command = <<-EOT
       echo "Waiting for uninstall to finish"
       sleep 42
       echo "Removing PDS Entry"
       bash scripts/rm-pds-entry.sh ${self.triggers.token_id} ${self.triggers.tenant_id} local.extd.cluster-id
      EOT
      interpreter = ["/bin/bash", "-c"]
      working_dir = path.module
  }
}

resource "null_resource" "scaleup" {
  depends_on = [null_resource.local_setup, local_file.cluster-config-vars]
  count = var.scaleup ? 1 : 0
  triggers = {
    ncount = var.nodes_count
    bm_ips = join(",", reverse(equinix_metal_device.baremachines.*.access_public_ipv4))
    scount = var.scale_count
  }
  provisioner "local-exec" {
    when = create
    command     = "/bin/bash add-node.sh ${join(" ", slice(reverse(equinix_metal_device.baremachines.*.access_public_ipv4), 0, var.scale_count))}"
    #command     = "/bin/bash add-node.sh ${element(equinix_metal_device.baremachines.*.access_public_ipv4, length(equinix_metal_device.baremachines.*.access_public_ipv4)-1)}"
    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    when = destroy
    command     = "echo 'Task to maintain states'"
    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module
  }
}

resource "null_resource" "scaledown" {
  depends_on = [
    equinix_metal_device.baremachines, local_file.cluster-config-vars
    #equinix_metal_ssh_key.ssh_pub_key
  ]
  #count = var.scaledown ? 0 : 1
  #count = !var.scaledown || var.scaleup ? 1 : 0
  #count = !var.scaledown || var.scaleup ? 1 : 0
  #count = var.nodes_count
  triggers =  {
  #  #condition = var.nodes_count
    ncount = var.nodes_count
  #  bm_ips = join(",", reverse(equinix_metal_device.baremachines.*.access_public_ipv4))
  #  scount = var.scale_count
  #  sdown = var.scaledown
  }
  provisioner "local-exec" {
    when = create
    #command = "/bin/bash remove-node.sh ${join(" ", slice(split(",", self.triggers.bm_ips), 0, self.triggers.scount))}"
    #command     = "if [ ${self.triggers.sdown} != true ] ; then /bin/bash remove-node.sh ${join(" ", slice(split(",", self.triggers.bm_ips), 0, self.triggers.scount))}; else echo 'Task done'; fi"
    command = "if ${var.scaledown} == true ; then /bin/bash remove-node.sh ${join(" ", slice(reverse(equinix_metal_device.baremachines.*.access_public_ipv4), 0, var.scale_count))} ; else echo 'Task done'; fi"
    #command     = "/bin/bash remove-node.sh ${element(equinix_metal_device.baremachines.*.access_public_ipv4, length(equinix_metal_device.baremachines.*.access_public_ipv4)-1)}"
    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module
  }

  provisioner "local-exec" {
    when = destroy
    command     = "echo 'Task to maintain states'"
    interpreter = ["/bin/bash", "-c"]
    working_dir = path.module
  }
  lifecycle {
    create_before_destroy = true
  }
}


output "info_bares_ips" {
  value = equinix_metal_device.baremachines.*.access_public_ipv4
}

output "info_bares_names" {
  value = equinix_metal_device.baremachines.*.hostname
}
